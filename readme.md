## 


backup dir
```
udisksctl unlock -b /dev/sda1
udisksctl mount -b /dev/mapper/luks-815994a7-a1aa-491c-8481-e3a1fb2599c1
```


```
make new-pair
```

export the GNUPGHOME

1. add uids
2. sign with `gpg --expert --default-key me@mail.com --edit-key me@mail.com`


```
make export
```


then move the keys to smartcard
