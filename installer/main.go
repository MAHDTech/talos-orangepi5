package main

import (
	_ "embed"
	"fmt"
	"os"
	"path/filepath"

	"github.com/siderolabs/go-copy/copy"
	"github.com/siderolabs/talos/pkg/machinery/overlay"
	"github.com/siderolabs/talos/pkg/machinery/overlay/adapter"
	"golang.org/x/sys/unix"
)

const name = "orangepi-5"

var kernelArgs = []string{
	"console=tty1",
	"console=ttyS2:1500000",
	"sysctl.kernel.kexec_load_disabled=1",
	"talos.dashboard.disabled=1",
}

type boardExtraOptions struct {}

type BoardInstaller struct{}

func (i *BoardInstaller) GetOptions(extra boardExtraOptions) (overlay.Options, error) {
	return overlay.Options{
		Name:       name,
		KernelArgs: kernelArgs,
	}, nil
}

func (i *BoardInstaller) Install(options overlay.InstallOptions[boardExtraOptions]) error {
	// Mount disk
	var f *os.File
	f, err := os.OpenFile(options.InstallDisk, os.O_RDWR|unix.O_CLOEXEC, 0o666)
	if err != nil {
		return fmt.Errorf("failed to open %s: %w", options.InstallDisk, err)
	}
	defer f.Close() //nolint:errcheck
	err = f.Sync()
	if err != nil {
		return err
	}

	// Copy dtbs
	if err := os.MkdirAll(filepath.Join(options.MountPrefix, "/boot/EFI"), 0o666); err != nil {
		return err
	}

	if err := copy.Dir(filepath.Join(options.ArtifactsPath, "/dtb"), filepath.Join(options.MountPrefix, "/boot/EFI/dtb")); err != nil {
		return err
	}

	return nil
}

func Copy(src, dest string) error {
	err := os.MkdirAll(filepath.Dir(dest), 0o666)
	if err != nil {
		return err
	}

	return copy.File(src, dest)
}

func main() {
	adapter.Execute(&BoardInstaller{})
}
