(list
 (channel
  (name 'guix.git)
  (url "https://codeberg.org/guix/guix.git")
  (introduction
   (make-channel-introduction
    "b68a2452fae5ab8ae5543a9e5470e978fa47066a"
    (openpgp-fingerprint "3CE4 6455 8A84 FDC6 9DB4 0CFB 090B 1199 3D9A EBB5")))

 (channel
  (name 'sjtug)
  (url "https://mirrors.sjtug.sjtu.edu.cn/guix")
  (branch "master"))

 (channel
  (name 'guix)
  (url "https://bordeaux.guix.gnu.org/git/guix.git")
  (branch "master"))

 (channel
  (name 'nonguix)
  (url "https://gitlab.com/nonguix/nonguix")
  (introduction
   (make-channel-introduction
    "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
    (openpgp-fingerprint "2A39 3FFF 68F4 EF7A 3D29 12AF 6FEC 97B1 8B7D 734B")))
  (package-mirrors
   (list (mirror
          (url "https://nonguix-proxy.ditigal.xyz/")
          (signature-query (skip)))))
