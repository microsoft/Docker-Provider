# Mariner Development
## Links
* Official eng.hub docs: [aka.ms/mariner](https://aka.ms/mariner)
* View current [container images](https://eng.ms/docs/products/mariner-linux/gettingstarted/containers/marinercontainerimage)
* View available [packages](https://eng.ms/docs/products/mariner-linux/gettingstarted/packages/packagesx) and how to request additional ones
* Info about the [secure supply chain initiative](https://eng.ms/docs/more/containers-secure-supply-chain/) for containers

## Mariner vs. Ubuntu
Mariner is an RPM-based distro whereas Ubuntu is Debian-based. Mariner uses `tdnf` as its package manager whereas Ubuntu uses `apt`. The largest difference between the two then is replacing all the `apt` commands with `tdnf`. [This table](https://eng.ms/docs/products/mariner-linux/gettingstarted/ubuntu/atlas#command-replacement-reference-table) provides all the equivalent commands between the two. Not all commands are available with `tdnf`, which is a trimmed-down C-based version of the `dnf` package manager. `dnf` can be installed by `tdnf` with `tdnf install -y dnf` if some extra commands are needed. Using `dnf` was useful for debugging to find which repo a package was coming or if it had a different name compared to the Ubuntu package.

More info about `apt` vs `tdnf` can be found [here](https://eng.ms/docs/products/mariner-linux/onboarding/packaging/packagemanagement).

## Adding an RPM Repository
New repositories are added with a `*.repo` file stored in the `/etc/yum.repos.d/` directory.

Mariner by default has certain repo files in the container already. These include the repos for the mariner base and mariner extended packages.

`azure-mdsd` is in the `Mariner-extras` repository.

## Distroless Containers
Distroless containers exclude packages provided by the distro such as a shell and package manager. They provide a slimmed down image with a smaller attack surface. We will still need a shell for our `main.sh` script and any debugging done by exec-ing into the container. But a distroless base image is still useful to not have the package managers and any unecessary packages which are needed solely for building and not at runtime. This is especially useful since `tdnf` does not have an `autoremove` command and using the distroless container trims down the size quite a bit.

### Docker Multi-Stage Builds
Since the distroless container does not have a package manager, we will still need a way to install all the necessary packages. The standard way to do this for distroless containers is through [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/). The first build uses the regular base container and sets up everything as normal up until adding the entry command as running the `main.sh` script.

The second build uses the distroless image as the base image. Only the files we need at runtime are copied over from the first build. An example of this is [here](https://medium.com/@alexanto222/hardening-of-docker-images-distroless-images-d6d87b591a59).

Note that this means that any new files added while developing will need to be copied over to the distroless build stage. Everything under `/opt` is currently copied over. See below for the steps to take when adding a new package.

If you are building locally, you will need to set `DOCKER_BUILDKIT=1` because of [this](https://github.com/moby/moby/issues/37965) Docker bug. This has been set in our github actions builds.


### Using the Shell in the Distroless Container
`bash` is still copied over into our container to be able to run our `main.sh` bash script. However, there are some interface issues with `bash` on the distroless container. Mariner has default support for using `busybox` as the shell for debugging. This however changes some of the commands when exec-ing into the container which I have noted below. Feel free to add more here if you find them.

  | Old Command | New Command |
  | --- | --- |
  | `ps -aux` | `ps` |

Note: You can still call `kubectl exec -it <pod name> -- bash`, there will just be a weird warning from `busybox` in the beginning.


## Adding or Upgrading a New Package
### Base Image
You can start to add a package by including `tdnf install -y <package name>` in the `builder` Docker stage and trying to build to see if the package is available. `tdnf` will search all repos for the package and print out an error if it cannot be found.

Some naming conventions or package names are different for RPM packages. For example, `*-dev` and `*-debug` for Ubuntu packages vs. `*-devel` and `*-debugsymbol` for RPM pacakges. Similarly, `cron` has an equivalent RPM package called `cronie` and the name of the executable is `crond`. A package you are looking for may be provided by Mariner but under a different name. For example, `libre2` is just `re2` in the Mariner repository.

`dnf` has a command called `whatprovides` to help with this as explained [here](https://eng.ms/docs/products/mariner-linux/onboarding/packaging/packagemanagement#finding-the-right-package), but usually a quick internet search will also work.

## Our Current Package Dependencies
* All Mariner packages are supported for both AMD64 and ARM64.
* `telegraf`, `fluent-bit` are built and published by the Mariner team in the [Mariner base repository](https://packages.microsoft.com/cbl-mariner/2.0/prod/base/x86_64/). [ARM64 versions](https://packages.microsoft.com/cbl-mariner/2.0/prod/base/aarch64/) are available also.
* `azure-mdsd` is published by their team to the Mariner extras repository. [Release notes](https://eng.ms/docs/products/geneva/collect/instrument/linux/releasenotes). The package for [Mariner 2.0](https://packages.microsoft.com/cbl-mariner/2.0/prod/extras/x86_64/) is now available.
* When updating any package, make sure to check the dependencies and add if any changes. (Avoid removing unless you are completely sure that non other packages have those dependencies as some dependencies in the list may also be used by some other package.)

### Get dependencies for the distroless image
To get the .so file dependencies, run:
  * `which <executable>` to get the executable path
  * `ldd <executable path>` to get the list of dependencies
  * This will print out something similar to:

    ```
    linux-vdso.so.1 (0x00007ffc2eb6e000)
    libselinux.so.1 => /lib/libselinux.so.1 (0x00007f7677a6a000)
    libpam.so.0 => /lib/libpam.so.0 (0x00007f7677a58000)
    libc.so.6 => /lib/libc.so.6 (0x00007f7677856000)
    libpcre.so.1 => /lib/libpcre.so.1 (0x00007f76777df000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f7677b30000)
    libaudit.so.1 => /lib/libaudit.so.1 (0x00007f76777ae000)
    ```

  * Packages without `=>` do not need to be copied as these will already be present in the distroless container
If some files are missing after the `=>`, you can run these commands in a container that is using the base image instead of the distroless image to see which files need to be copied over

In the Dockerfile in the distroless stage:
  * Copy over the executable file path
  * Copy over the full path of all `.so` files that have `=>`
  * If not all necssary `.so` files are available, there will be an error saying that file is missing during runtime
