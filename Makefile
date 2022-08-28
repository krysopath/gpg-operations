EMAIL = krysopath@gmail.com
NAME = krysopath
CYCLE = 2y

DERIVE = derive -b 64 -f base64 -v 9999 gpg
BACKUP_PATH = /media/gve/00149bfb-5a89-4f41-a6a5-4e56d20b34b0/gpg-operations/keys

define GPGCONF
personal-cipher-preferences AES256 AES192 AES
personal-digest-preferences SHA512 SHA384 SHA256
personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
cert-digest-algo SHA512
s2k-digest-algo SHA512
s2k-cipher-algo AES256
charset utf-8
fixed-list-mode
no-comments
no-emit-version
keyid-format 0xlong
list-options show-uid-validity
verify-options show-uid-validity
with-fingerprint
require-cross-certification
no-symkey-cache
use-agent
throw-keyids

endef

export GPGCONF
deps:
	sudo apt install libyubikey-udev 

new-pair:
	@export PASS=$$( $(DERIVE) ); \
	export GNUPGHOME=$$(mktemp -d -t gnupg_$$(date +%Y%m%d%H%M)_XXX); \
	echo "$$GPGCONF" > $$GNUPGHOME/gpg.conf; \
	echo $$PASS | gpg \
          --pinentry-mode loopback \
          --batch \
          --passphrase-file /dev/stdin \
          --quick-generate-key '$(NAME) <$(EMAIL)>' ed25519 cert never; \
	export KEYID=$$(gpg --list-keys --with-colons "$(EMAIL)" | grep '^pub' | cut -d: -f5); \
	export FPR=$$(gpg --list-keys --with-colons "$(EMAIL)" | grep '^fpr' | sed -n 1p | cut -d: -f10); \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--quick-add-key "$${FPR}" ed25519 sign 1y; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--quick-add-key "$${FPR}" cv25519 encr 1y; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--quick-add-key "$${FPR}" ed25519 auth 1y; \
	export DIR=$(BACKUP_PATH)/$(EMAIL); \
	rm -rf $$DIR ; cp -r $$GNUPGHOME $$DIR ; rm -rf $$GNUPGHOME ; \
	printf "new key in:\nexport GNUPGHOME=$$DIR"

rotate/S:
	@export PASS=$$( $(DERIVE) ); \
	export FPR=$$(gpg --list-keys --with-colons "$(EMAIL)" | grep '^fpr' | sed -n 1p | cut -d: -f10); \
	gpg --list-secret-keys "$$FPR" | grep -oP '(?<=ed25519/)\w+(?=\s[0-9]{4}-[0-9]{2}-[0-9]{2}\s\[S\])' \
	|  xargs -I{} sh -c "gpg --yes --delete-secret-and-public-keys '{}!'"; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--quick-add-key "$${FPR}" ed25519 sign 1y; 


rotate/A:
	@export PASS=$$( $(DERIVE) ); \
	export FPR=$$(gpg --list-keys --with-colons "$(EMAIL)" | grep '^fpr' | sed -n 1p | cut -d: -f10); \
	gpg --list-secret-keys "$$FPR" | grep -oP '(?<=ed25519/)\w+(?=\s[0-9]{4}-[0-9]{2}-[0-9]{2}\s\[A\])' \
	|  xargs -I{} sh -c "gpg --yes --delete-secret-and-public-keys '{}!'"; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--quick-add-key "$${FPR}" ed25519 sign 1y; 

rotate/E:
	@export PASS=$$( $(DERIVE) ); \
	export FPR=$$(gpg --list-keys --with-colons "$(EMAIL)" | grep '^fpr' | sed -n 1p | cut -d: -f10); \
	gpg --list-secret-keys "$$FPR" | grep -oP '(?<=cv25519/)\w+(?=\s[0-9]{4}-[0-9]{2}-[0-9]{2}\s\[E\])' \
	|  xargs -I{} sh -c "gpg --yes --delete-secret-and-public-keys '{}!'"; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--quick-add-key "$${FPR}" cv25519 encr 1y; 

rotate/all: rotate/S rotate/A rotate/E

keytocard:
	bash yubikey.sh smartcard

set-yubikey:
	BACKUP_PATH=$(BACKUP_PATH) bash yubikey.sh ykman

export:
	@export PASS=$$( derive -b 64 -f base64 -v 9999 gpg ); \
	export FPR=$$(gpg --list-keys --with-colons "$(EMAIL)" | grep '^fpr' | sed -n 1p | cut -d: -f10); \
	gpg --keyserver keyserver.ubuntu.com --send-keys $$FPR; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--armor --export $$KEYID > $(BACKUP_PATH)/$(EMAIL)_pub.asc; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--armor --export-secret-keys $$KEYID > $(BACKUP_PATH)/$(EMAIL)_priv.asc; \
	echo $$PASS | gpg \
		--pinentry-mode loopback \
		--batch --passphrase-file /dev/stdin \
		--armor --export-secret-subkeys $$KEYID > $(BACKUP_PATH)/$(EMAIL)_ssb.asc; \

