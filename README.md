# Zom Prosody Modules

Custom module versions that Zom relies on.

Generally we prefer stability over new-hotness, so we use the stable modules
shipped in our prosody distribution. However, in some cases we may want a new
bugfix or some new feature, so we cherry-pick those modules into this dir.

Also, if a module doesn't exist in the prosody-modules repo, then we can
include it here easily.

**Warning**: This directory is used as-is during a zom deployment, so don't
leave any half-baked changes in here or it might get pushed to production.

TODO: setup staging/prod variations on this

Sources:
* https://hg.prosody.im/prosody-modules
* https://github.com/chrisballinger/prosody-modules/commit/40486273306f13ea68236745858df9b95a07c4fb


## How to update a module?

TODO: automate this :|

Each module has a `source` file in that lists the current version of the
module, and where it was fetched from.

For most of the modules it is some particular commit from the main prosody
modules repo (see above).

To update a module:

1. go to the original source
2. find a newer/latest commit
3. download it into the dir
4. update the metadata in `source`
   easy command to update the hash:
   ```bash
   # run in module dir AFTER updating the module. this command will replace the
   # sha256sum line in ./source
   sed \$d source -i && echo "sha256sum: $(sha256sum  *.lua | awk '{print $1}')" >> source
   ```
5. TEST TEST TEST! Make sure the new module version is actually working in our
   version of prosody.

Why include the hash? In case there is ever any question as to which version
a zom server is running, simply hash it and compare it!


## License

All modules are individually licensed, see module file header for details.
