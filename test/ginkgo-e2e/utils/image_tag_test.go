package utils

import "testing"

func TestImageTag(t *testing.T) {
	cases := []struct {
		name     string
		imageRef string
		want     string
	}{
		// The tag the agent reports back as customDimensions.Version.
		{"linux agent", "mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.8.0-ci-prod-09-06-2026-fd42f68c", "3.8.0-ci-prod-09-06-2026-fd42f68c"},
		{"windows agent", "mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.8.0-ci-prod-09-06-2026-fd42f68c", "win-3.8.0-ci-prod-09-06-2026-fd42f68c"},
		// A digest is stripped first, so a reference pinning both still yields its tag.
		{"tag and digest", "mcr.microsoft.com/geneva/mdsd:recommended@sha256:abc", "recommended"},
		// Nothing to match the reported version against.
		{"digest only", "mcr.microsoft.com/oss/v2/calico/node@sha256:69124ac", ""},
		{"bare reference", "mcr.microsoft.com/oss/v2/kubernetes/pause", ""},
		// The port of a registry host must never be mistaken for a tag.
		{"registry port, no tag", "localhost:5000/ciprod", ""},
		{"registry port and tag", "localhost:5000/ciprod:3.8.0", "3.8.0"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := ImageTag(tc.imageRef); got != tc.want {
				t.Fatalf("ImageTag(%q) = %q, want %q", tc.imageRef, got, tc.want)
			}
		})
	}
}
