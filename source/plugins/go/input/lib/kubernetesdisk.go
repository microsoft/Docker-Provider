package lib

import (
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/shirou/gopsutil/v4/disk"
)

func init() {
	var logPath string
	if strings.EqualFold(osType, "windows") {
		logPath = "/etc/amalogswindows/fluent-bit-disk.log"
	} else {
		logPath = "/var/opt/microsoft/docker-cimprov/log/fluent-bit-disk.log"
	}

	isTestEnv := os.Getenv("GOUNITTEST") == "true"
	if isTestEnv {
		logPath = "./fluent-bit-disk.log"
	}

	FLBLogger = CreateLogger(logPath)
}

func GetDiskUsage(mountPointFilter, mountOptsExclude, fstypeExclude []string) ([]map[string]interface{}, error) {
	// Example usage of DiskUsage function
	disks, partitions, err := GetDiskUsageHelper([]string{"C:"}, []string{}, []string{"tmpfs"})
	if err != nil {
		FLBLogger.Printf("error getting disk usage info: %v", err)
		return nil, err
	}

	var results []map[string]interface{}

	FLBLogger.Printf("getting disk usage info: 1")

	for i, du := range disks {
		if du.Total == 0 {
			FLBLogger.Printf("getting disk usage info: 2")
			// Skip dummy filesystem (procfs, cgroupfs, ...)
			continue
		}

		device := partitions[i].Device
		mountOpts := mountOptions(partitions[i].Opts)
		tags := map[string]string{
			"path":   du.Path,
			"device": strings.ReplaceAll(device, "/dev/", ""),
			"fstype": du.Fstype,
			"mode":   mountOpts.mode(),
		}

		FLBLogger.Printf("tags: %+v\n", tags)

		label, err := disk.Label(strings.TrimPrefix(device, "/dev/"))
		if err == nil && label != "" {
			tags["label"] = label
		}

		var usedPercent float64
		if du.Used+du.Free > 0 {
			usedPercent = float64(du.Used) /
				(float64(du.Used) + float64(du.Free)) * 100
		}

		fields := map[string]interface{}{
			"total":        du.Total,
			"free":         du.Free,
			"used":         du.Used,
			"used_percent": usedPercent,
		}

		FLBLogger.Printf("fields: %+v\n", fields)

		results = append(results, map[string]interface{}{
			"fields": fields,
			"tags":   tags,
		})
	}

	FLBLogger.Printf("Results: %+v\n", results)

	return results, nil
}

type mountOptions []string

func (opts mountOptions) mode() string {
	if opts.exists("rw") {
		return "rw"
	} else if opts.exists("ro") {
		return "ro"
	}
	return "unknown"
}

func (opts mountOptions) exists(opt string) bool {
	for _, o := range opts {
		if o == opt {
			return true
		}
	}
	return false
}

func GetDiskUsageHelper(mountPointFilter, mountOptsExclude, fstypeExclude []string) ([]*disk.UsageStat, []*disk.PartitionStat, error) {
	FLBLogger.Printf("getting disk usage info: 3")
	parts, err := Partitions(true)
	FLBLogger.Printf("getting disk usage info: 4")
	if err != nil {
		FLBLogger.Printf("error getting disk partitions: %v", err)
		return nil, nil, err
	}

	mountPointFilterSet := newSet()
	for _, filter := range mountPointFilter {
		mountPointFilterSet.add(filter)
	}
	mountOptFilterSet := newSet()
	for _, filter := range mountOptsExclude {
		mountOptFilterSet.add(filter)
	}
	fstypeExcludeSet := newSet()
	for _, filter := range fstypeExclude {
		fstypeExcludeSet.add(filter)
	}
	paths := newSet()
	for _, part := range parts {
		paths.add(part.Mountpoint)
	}

	// Autofs mounts indicate a potential mount, the partition will also be
	// listed with the actual filesystem when mounted.  Ignore the autofs
	// partition to avoid triggering a mount.
	fstypeExcludeSet.add("autofs")

	var usage []*disk.UsageStat
	var partitions []*disk.PartitionStat
	hostMountPrefix := ""

	// partitionRange:
	for i := range parts {
		FLBLogger.Printf("getting disk usage info: 5")
		p := parts[i]

		// for _, o := range p.Opts {
		// 	if !mountOptFilterSet.empty() && mountOptFilterSet.has(o) {
		// 		FLBLogger.Printf("getting disk usage info: 6")
		// 		continue partitionRange
		// 	}
		// }
		// If there is a filter set and if the mount point is not a
		// member of the filter set, don't gather info on it.
		// if !mountPointFilterSet.empty() && !mountPointFilterSet.has(p.Mountpoint) {
		// 	FLBLogger.Printf("getting disk usage info: 7")
		// 	continue
		// }

		// If the mount point is a member of the exclude set,
		// don't gather info on it.
		// if fstypeExcludeSet.has(p.Fstype) {
		// 	FLBLogger.Printf("getting disk usage info: 8")
		// 	continue
		// }

		// If there's a host mount prefix use it as newer gopsutil version check for
		// the init's mountpoints usually pointing to the host-mountpoint but in the
		// container. This won't work for checking the disk-usage as the disks are
		// mounted at HOST_MOUNT_PREFIX...
		mountpoint := p.Mountpoint
		// if hostMountPrefix != "" && !strings.HasPrefix(p.Mountpoint, hostMountPrefix) {
		// 	mountpoint = filepath.Join(hostMountPrefix, p.Mountpoint)
		// 	// Exclude conflicting paths
		// 	if paths.has(mountpoint) {
		// 		// if s.Log != nil {
		// 		// 	s.Log.Debugf("[SystemPS] => dropped by mount prefix (%q): %q", mountpoint, hostMountPrefix)
		// 		// }
		// 		continue
		// 	}
		// }

		FLBLogger.Printf("getting disk usage info: 9")
		du, err := PSDiskUsage(mountpoint)
		if err != nil {
			FLBLogger.Printf("error getting PS-188 disk usage info: %v", err)
			// if s.Log != nil {
			// 	s.Log.Debugf("[SystemPS] => unable to get disk usage (%q): %v", mountpoint, err)
			// }
			continue
		}

		du.Path = filepath.Join(string(os.PathSeparator), strings.TrimPrefix(p.Mountpoint, hostMountPrefix))
		du.Fstype = p.Fstype
		usage = append(usage, du)
		partitions = append(partitions, &p)
	}

	return usage, partitions, nil
}

type set struct {
	m map[string]struct{}
}

func (s *set) empty() bool {
	return len(s.m) == 0
}

func (s *set) add(key string) {
	s.m[key] = struct{}{}
}

func (s *set) has(key string) bool {
	var ok bool
	_, ok = s.m[key]
	return ok
}

func newSet() *set {
	s := &set{
		m: make(map[string]struct{}),
	}
	return s
}

func Partitions(all bool) ([]disk.PartitionStat, error) {
	return disk.Partitions(all)
}

func PSDiskUsage(path string) (*disk.UsageStat, error) {
	du, err := disk.Usage(path)
	if err != nil {
		FLBLogger.Printf("error getting PS disk usage info: %v", err)
		return nil, err
	}
	if du.Total == 0 {
		FLBLogger.Printf("error getting disk usage info: total size is zero")
		return nil, errors.New("total size is zero")
	}
	return du, nil
}
