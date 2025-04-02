package lib

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/shirou/gopsutil/v4/disk"
)

func main() {
	// Example usage of DiskUsage function
	disks, partitions, err := DiskUsage([]string{"C:"}, []string{}, []string{"tmpfs"})
	if err != nil {
		fmt.Printf("error getting disk usage info: %w", err)
	}
	for i, du := range disks {
		if du.Total == 0 {
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

		label, err := disk.Label(strings.TrimPrefix(device, "/dev/"))
		if err == nil && label != "" {
			tags["label"] = label
		}

		var usedPercent float64
		if du.Used+du.Free > 0 {
			usedPercent = float64(du.Used) /
				(float64(du.Used) + float64(du.Free)) * 100
		}

		var inodesUsedPercent float64
		if du.InodesUsed+du.InodesFree > 0 {
			inodesUsedPercent = float64(du.InodesUsed) /
				(float64(du.InodesUsed) + float64(du.InodesFree)) * 100
		}

		fields := map[string]interface{}{
			"total":               du.Total,
			"free":                du.Free,
			"used":                du.Used,
			"used_percent":        usedPercent,
			"inodes_total":        du.InodesTotal,
			"inodes_free":         du.InodesFree,
			"inodes_used":         du.InodesUsed,
			"inodes_used_percent": inodesUsedPercent,
		}
		fmt.Printf("Fields: %+v\n", fields)
		fmt.Printf("Tags: %+v\n", tags)
	}
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

func DiskUsage(mountPointFilter, mountOptsExclude, fstypeExclude []string) ([]*disk.UsageStat, []*disk.PartitionStat, error) {
	parts, err := Partitions(true)
	if err != nil {
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

partitionRange:
	for i := range parts {
		p := parts[i]

		for _, o := range p.Opts {
			if !mountOptFilterSet.empty() && mountOptFilterSet.has(o) {
				continue partitionRange
			}
		}
		// If there is a filter set and if the mount point is not a
		// member of the filter set, don't gather info on it.
		if !mountPointFilterSet.empty() && !mountPointFilterSet.has(p.Mountpoint) {
			continue
		}

		// If the mount point is a member of the exclude set,
		// don't gather info on it.
		if fstypeExcludeSet.has(p.Fstype) {
			continue
		}

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

		du, err := PSDiskUsage(mountpoint)
		if err != nil {
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
		return nil, err
	}
	if du.Total == 0 {
		return nil, errors.New("total size is zero")
	}
	return du, nil
}
