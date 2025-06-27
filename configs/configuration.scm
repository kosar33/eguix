(use-modules 
  (gnu) 
  (nonguix licenses) 
  (nonguix packages linux))

(operating-system
  (host-name "guix-ru")
  (timezone "Europe/Moscow")
  (locale "ru_RU.utf8")
  
  (kernel 
    (let ((base (customize-linux 
                 #:linux linux-lts
                 #:configs '("CONFIG_MICROCODE_AMD=y"))))
      (linux-with-firmware base (list linux-firmware))))
  
  (kernel-arguments
    '("quiet" "splash" 
      "libata.force=noncq"
      "radeon.si_support=0"
      "amdgpu.si_support=1"))
  
  (bootloader
    (bootloader-configuration
      (bootloader grub-efi-bootloader)
      (targets '("/boot/efi"))
      (keyboard-layout (keyboard-layout "us,ru" 
                      #:options '("grp:alt_shift_toggle"))))
  
  (file-systems
    (cons* (file-system
             (mount-point "/")
             (device (file-system-label "guix-root"))
             (type "ext4"))
           (file-system
             (mount-point "/boot/efi")
             (device (uuid "XXXX-XXXX"))
             (type "vfat"))
           %base-file-systems))
  
  (users
    (cons* (user-account
            (name "user")
            (comment "Российский пользователь")
            (group "users")
            (home-directory "/home/user")
            (supplementary-groups
              '("wheel" "audio" "video" "kvm")))
           %base-user-accounts))
  
  (services
    (cons* 
      (service dhcp-client-service-type)
      (service ntp-service-type)
      (service openssh-service-type)
      %base-services))
  
  (packages
    (cons* 
      amd-microcode
      mesa-opencl
      xf86-video-amdgpu
      %base-packages))
)
