with Files.File_System.Testing;
separate (Files_Suite.Operations)
   --  The root list shows "/" and what is mounted under the host's volume
   --  folders (Linux: /mnt, /media, /run/media; macOS: /Volumes,
   --  /System/Volumes) and the session's gvfs directory, never those folders
   --  themselves, nor another host's. Pure, so it holds on hosts whose
   --  folders are not mount points and where root discovery never meets it.
   procedure Test_User_Visible_Mount_Points (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Gvfs : constant String := "/run/user/1000/gvfs";

      --  Assert that Mount_Point is listed as a root exactly when Expected.
      procedure Check (Mount_Point : String; Expected : Boolean) is
      begin
         Assert
           (Files.File_System.Testing.Is_User_Visible_Mount_Point (Mount_Point, Gvfs) = Expected,
            Mount_Point & (if Expected then " is listed as a root" else " is not listed as a root"));
      end Check;
      Linux : constant Boolean := Hostkit.Host.Current = Hostkit.Host.Linux;
      MacOS : constant Boolean := Hostkit.Host.Current = Hostkit.Host.MacOS;
   begin
      Check ("/", True);
      Check ("/mnt", False);
      Check ("/mnt/usb", Linux);
      Check ("/media", False);
      Check ("/media/bent/X", Linux);
      Check ("/run/media", False);
      Check ("/run/media/u/X", Linux);
      Check ("/Volumes", False);
      Check ("/Volumes/X", MacOS);
      Check ("/home", False);
      Check (Gvfs & "/smb-share:x", True);
      Check (Gvfs, False);
      Check ("/System/Volumes", False);
      Check ("/System/Volumes/Data", MacOS);
      --  A name that only starts like a container is not in it.
      Check ("/mntx/usb", False);
      Check ("/Volumesque/X", False);
      Check ("/run/media2/u/X", False);
      Check (Gvfs & "-other/x", False);
      --  No gvfs directory in this session: nothing is under it.
      Assert (not Files.File_System.Testing.Is_User_Visible_Mount_Point (Gvfs & "/smb-share:x", ""),
              "without a session gvfs directory its old path is not a root");
      Assert (not Files.File_System.Testing.Is_User_Visible_Mount_Point ("/x", ""),
              "an empty gvfs directory does not make every path a root");
   end Test_User_Visible_Mount_Points;
