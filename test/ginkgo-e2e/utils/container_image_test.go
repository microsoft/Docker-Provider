package utils

import "testing"

func TestDigestPinnedImageName(t *testing.T) {
	cases := []struct {
		name     string
		imageRef string
		want     string
	}{
		// Real references observed on ci-logs-prod-wcus-fips.
		{"digest only", "mcr.microsoft.com/oss/v2/calico/node@sha256:69124ac", "oss/v2/calico/node"},
		{"digest only, init container", "mcr.microsoft.com/oss/v2/calico/pod2daemon-flexvol@sha256:1990d55", "oss/v2/calico/pod2daemon-flexvol"},
		// Both tag and digest: the agent keeps the tag, so this must not be excluded.
		{"tag and digest", "mcr.microsoft.com/geneva/mdsd:recommended@sha256:abc", ""},
		// No digest at all: the agent sets the tag, or defaults it to latest.
		{"tag only", "mcr.microsoft.com/aks/msi/addon-token-adapter:master.260209.2", ""},
		{"bare reference", "mcr.microsoft.com/oss/v2/kubernetes/pause", ""},
		{"no registry, digest only", "myimage@sha256:abc", "myimage"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := digestPinnedImageName(tc.imageRef); got != tc.want {
				t.Fatalf("digestPinnedImageName(%q) = %q, want %q", tc.imageRef, got, tc.want)
			}
		})
	}
}

func TestBuildImageExclusionFilter(t *testing.T) {
	if got := BuildImageExclusionFilter(nil); got != "" {
		t.Fatalf("expected no filter for an empty list, got %q", got)
	}

	want := ` | where Image !in ("oss/v2/calico/node", "oss/v2/calico/typha")`
	if got := BuildImageExclusionFilter([]string{"oss/v2/calico/node", "oss/v2/calico/typha"}); got != want {
		t.Fatalf("got %q, want %q", got, want)
	}

	if got := BuildImageExclusionFilter([]string{`bad"name`}); got != "" {
		t.Fatalf("expected quoted names to be dropped, got %q", got)
	}
}
