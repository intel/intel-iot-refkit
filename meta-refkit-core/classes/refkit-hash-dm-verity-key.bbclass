# Recipes which use the file pointed to by REFKIT_DMVERITY_PRIVATE_KEY
# must inherit this class and then make all functions which use the
# file depend on REFKIT_DMVERITY_PRIVATE_KEY_HASH.
#
# The hash is calculated by this class. When the file changes,
# the hash changes, and thus whatever depends on the file
# content gets redone.
#
# Always errors out early during parsing when the key is set and not found.
# Optionally skips the recipe when the key is unset.

REFKIT_DM_VERITY_KEY_NEEDED ?= "0"
REFKIT_DMVERITY_PRIVATE_KEY_HASH = ""

python () {
    import os
    import hashlib

    privkey = d.getVar('REFKIT_DMVERITY_PRIVATE_KEY')
    if not privkey:
        if oe.types.boolean(d.getVar('REFKIT_DM_VERITY_KEY_NEEDED')):
            # skip recipe
            raise bb.parse.SkipRecipe('REFKIT_DMVERITY_PRIVATE_KEY is not set.')
        else:
            # Not an error, the key is not actually needed.
            return
    if not os.path.isfile(privkey):
        # An invalid value however is a parse error, always.
        bb.fatal('REFKIT_DMVERITY_PRIVATE_KEY=%s is not a file.' % privkey)
    with open(privkey, 'rb') as f:
        data = f.read()
    hash = hashlib.sha256(data).hexdigest()
    d.setVar('REFKIT_DMVERITY_PRIVATE_KEY_HASH', hash)

    # Must reparse and thus rehash on file changes.
    bb.parse.mark_dependency(d, privkey)
}
