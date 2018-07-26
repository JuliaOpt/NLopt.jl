using BinaryProvider # requires BinaryProvider 0.3.0 or later
include("compile.jl")

# env var to force compilation from source, for testing purposes
const forcecompile = get(ENV, "FORCE_COMPILE_nlopt", "no") == "yes"

# Parse some basic command-line arguments
const verbose = ("--verbose" in ARGS) || forcecompile
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, String["libnlopt_cxx"], :libnlopt),
]
verbose && forcecompile && @info("Forcing compilation from source.")

# Download binaries from hosted location
bin_prefix = "https://github.com/stevengj/NLoptBuilder/releases/download/v2.5.0-a1"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, :glibc) => ("$bin_prefix/NLopt.v1.0.0.aarch64-linux-gnu.tar.gz", "929a72fef2b54bbadc49e32f95e22a977aae2b01e9e8de0e9576abc6d7284553"),
    Linux(:aarch64, :musl) => ("$bin_prefix/NLopt.v1.0.0.aarch64-linux-musl.tar.gz", "f519524a11edce841d5233079638e14340d759712992221aa5916bcd42f4c40b"),
    Linux(:armv7l, :glibc, :eabihf) => ("$bin_prefix/NLopt.v1.0.0.arm-linux-gnueabihf.tar.gz", "f22e9559cf7de9fbc3a7839affb3f4291f3e7617453725e8dcd26201a18e655b"),
    Linux(:armv7l, :musl, :eabihf) => ("$bin_prefix/NLopt.v1.0.0.arm-linux-musleabihf.tar.gz", "4bedd664f512c07879dbebd2cc741b04b14c36937077daba40e094a3459a09c7"),
    Linux(:i686, :glibc) => ("$bin_prefix/NLopt.v1.0.0.i686-linux-gnu.tar.gz", "ff9060494dc55c3a71dca479313d8e77dd73fe55d76fefc6130e24595dc57a98"),
    Linux(:i686, :musl) => ("$bin_prefix/NLopt.v1.0.0.i686-linux-musl.tar.gz", "d34524fa69a7bc87ec197ace0ab9bb499c0a5f13edabc57fa7119b010ebb4dc8"),
    Windows(:i686) => ("$bin_prefix/NLopt.v1.0.0.i686-w64-mingw32.tar.gz", "a35330d84df05bd01fd6639b4aa0cc405d45496a78e266eeb734dc0bf8ef7dea"),
    Linux(:powerpc64le, :glibc) => ("$bin_prefix/NLopt.v1.0.0.powerpc64le-linux-gnu.tar.gz", "790701b231ce852a2a4b983bd9defa631037773752dd10de989218f8bdbb3c39"),
    MacOS(:x86_64) => ("$bin_prefix/NLopt.v1.0.0.x86_64-apple-darwin14.tar.gz", "8b452364a48e4c4a64ee53720ba6d10c349670b456111a958ffe6306e155b3e7"),
    Linux(:x86_64, :glibc) => ("$bin_prefix/NLopt.v1.0.0.x86_64-linux-gnu.tar.gz", "f342e84cc2f33ac6ed48daedeb6d04984e331ef3e609253c5cc4566adbc32fef"),
    Linux(:x86_64, :musl) => ("$bin_prefix/NLopt.v1.0.0.x86_64-linux-musl.tar.gz", "84f7c1d87931596fbed03cdae2f17533dc9e3dd0e0b2dca0ef754d212e6f0368"),
    FreeBSD(:x86_64) => ("$bin_prefix/NLopt.v1.0.0.x86_64-unknown-freebsd11.1.tar.gz", "570883992f1f0589aa102cd5b349fa5dda4be86da42c6036591403817f916a08"),
    Windows(:x86_64) => ("$bin_prefix/NLopt.v1.0.0.x86_64-w64-mingw32.tar.gz", "c62e70431c4c295102881a76f45e1b26875dbb3f6c18e175fe184fef4b301ee2"),
)

# source code tarball and hash for fallback compilation
source_url = "https://github.com/stevengj/nlopt/releases/download/nlopt-2.4.2/nlopt-2.4.2.tar.gz"
source_hash = "8099633de9d71cbc06cd435da993eb424bbcdbded8f803cdaa9fb8c6e09c8e89"

# Install unsatisfied or updated dependencies:
unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
if haskey(download_info, platform_key()) && !forcecompile
    url, tarball_hash = download_info[platform_key()]
    if !isinstalled(url, tarball_hash; prefix=prefix)
        # Download and install binaries
        install(url, tarball_hash; prefix=prefix, force=true, verbose=verbose)

        # check again whether the dependency is satisfied, which
        # may not be true if dlopen fails due to a libc++ incompatibility (#50)
        unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
    end
end

if unsatisfied || forcecompile
    # Fall back to building from source, giving the library a different name
    # so that it is not overwritten by BinaryBuilder downloads or vice-versa.
    libname = "libnlopt_from_source"
    products = [ LibraryProduct(prefix, [libname], :libnlopt) ]
    source_path = joinpath(prefix, "downloads", "src.tar.gz")
    if !isfile(source_path) || !verify(source_path, source_hash; verbose=verbose) || !satisfied(products[1]; verbose=verbose)
        compile(libname, source_url, source_hash, prefix=prefix, verbose=verbose)
    end
end

# Write out a deps.jl file that will contain mappings for our products
write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)
