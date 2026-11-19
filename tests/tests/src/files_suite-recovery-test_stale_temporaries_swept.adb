with Ada.Streams;
with Files.Durable_Writes;
with Files_Suite.Support.Disk;
separate (Files_Suite.Recovery)
   --  The temporaries a crash left beside a file are swept before it is
   --  written again -- only ones files itself could have made and left:
   --  named as its temporaries are, regular files of this user that nobody
   --  else may read, written before this process started. And a name that
   --  is taken is told apart from any other refusal to create a temporary.
   procedure Test_Stale_Temporaries_Swept (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base     : constant String := Join (Root, "settings.txt");
      Old_Time : constant GNAT.OS_Lib.OS_Time := GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5);
      Identity : Unbounded_String;
      Taken    : Boolean;
      Raised   : Boolean;

      procedure Write_Text (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Write (Stream, "left behind");
      end Write_Text;

      --  An owner-only file at Path, last written long before this run.
      procedure Make_Stale (Path : String) is
      begin
         Files.Durable_Writes.Write_Private_File (Path, Write_Text'Access, Identity);
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Path, Old_Time);
      end Make_Stale;
   begin
      Reset_Root;
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Files_Suite.Support.Skip
           ("Test_Stale_Temporaries_Swept", "only where mode bits are native can a temporary be shown owner-only");
         return;
      end if;
      Make_Stale (Base & ".tmp");
      Make_Stale (Base & ".tmp-17");
      --  Readable by others: not one of files' own temporaries.
      Write_Binary_File (Base & ".tmp-2", "someone else's");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Base & ".tmp-2", Old_Time);
      Assert
        (Files.File_System.Permissions.Set_Permissions (Base & ".tmp-2", 8#644#).Success,
         "prepare a temporary others may read");
      --  Written since this process started: perhaps another writer's.
      Files.Durable_Writes.Write_Private_File (Base & ".tmp-3", Write_Text'Access, Identity);
      --  Named otherwise, a folder, and a link: never one of its temporaries.
      Make_Stale (Base & ".tmpx");
      Make_Stale (Base & ".tmp-0");
      Ada.Directories.Create_Directory (Base & ".tmp-5");
      declare
         Linked : constant Boolean := Files_Suite.Support.Disk.Create_Symlink (Base & ".tmp-17", Base & ".tmp-6");
      begin
         Files.Durable_Writes.Sweep_Stale_Temporaries (Base);
         Assert (not Ada.Directories.Exists (Base & ".tmp"), "a stale temporary is swept");
         Assert (not Ada.Directories.Exists (Base & ".tmp-17"), "a numbered stale temporary is swept");
         Assert (Ada.Directories.Exists (Base & ".tmp-2"), "one others may read is kept");
         Assert (Ada.Directories.Exists (Base & ".tmp-3"), "one written since this process started is kept");
         Assert (Ada.Directories.Exists (Base & ".tmpx"), "a file named otherwise is kept");
         Assert (Ada.Directories.Exists (Base & ".tmp-0"), "a number files never gives is kept");
         Assert (Ada.Directories.Exists (Base & ".tmp-5"), "a folder is kept");
         if Linked then
            Assert (Hostkit.Fs.Is_Link (Base & ".tmp-6"), "a link is kept");
         end if;
      end;

      --  A taken name, and a create refused for another reason.
      Files.Durable_Writes.Write_Private_File (Base & ".tmp-3", Write_Text'Access, Identity, Taken);
      Assert (Taken, "a create refused by an entry there says the name is taken");
      Files_Suite.Support.Assert_Equal
        (Ada.Strings.Unbounded.Length (Identity), 0, "a taken name returns no identity");
      Assert (File_Has_Bytes (Base & ".tmp-3", "left behind"), "and the entry there is kept as it was");
      Raised := False;
      begin
         Files.Durable_Writes.Write_Private_File
           (Join (Join (Root, "no-such-folder"), "x.tmp"), Write_Text'Access, Identity, Taken);
      exception
         when Ada.IO_Exceptions.Use_Error =>
            Raised := True;
      end;
      Assert (Raised, "a create refused for want of its folder is not a taken name: it raises");
      Files_Suite.Support.Assert_Equal
        (Ada.Strings.Unbounded.Length (Identity), 0, "a refused create returns no identity");
   end Test_Stale_Temporaries_Swept;
