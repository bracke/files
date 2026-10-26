separate (Files_Suite.Operations)
   --  The root list shows "/" and what is mounted under /mnt, /media,
   --  /run/media, /Volumes, /System/Volumes and the session's gvfs directory, never those
   --  containers themselves. Pure, so it holds on hosts whose containers are
   --  not mount points and where root discovery never meets the case.
   procedure Test_User_Visible_Mount_Points (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gvfs : constant String := "/run/user/1000/gvfs";

      --  Assert that Mount_Point is listed as a root exactly when Expected.
      procedure Check (Mount_Point : String; Expected : Boolean) is
      begin
         Assert
           (Files.File_System.Is_User_Visible_Mount_Point (Mount_Point, Gvfs) = Expected,
            Mount_Point & (if Expected then " is listed as a root" else " is not listed as a root"));
      end Check;
   begin
      Check ("/", True);
      Check ("/mnt", False);
      Check ("/mnt/usb", True);
      Check ("/media", False);
      Check ("/media/bent/X", True);
      Check ("/run/media", False);
      Check ("/run/media/u/X", True);
      Check ("/Volumes", False);
      Check ("/Volumes/X", True);
      Check ("/home", False);
      Check (Gvfs & "/smb-share:x", True);
      Check (Gvfs, False);
      Check ("/System/Volumes", False);
      Check ("/System/Volumes/Data", True);
      --  A name that only starts like a container is not in it.
      Check ("/mntx/usb", False);
      Check ("/Volumesque/X", False);
      Check ("/run/media2/u/X", False);
      Check (Gvfs & "-other/x", False);
      --  No gvfs directory in this session: nothing is under it.
      Assert (not Files.File_System.Is_User_Visible_Mount_Point (Gvfs & "/smb-share:x", ""),
              "without a session gvfs directory its old path is not a root");
      Assert (not Files.File_System.Is_User_Visible_Mount_Point ("/x", ""),
              "an empty gvfs directory does not make every path a root");
   end Test_User_Visible_Mount_Points;
