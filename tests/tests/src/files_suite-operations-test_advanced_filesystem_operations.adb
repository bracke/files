separate (Files_Suite.Operations)
   procedure Test_Advanced_Filesystem_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sources  : Files.Types.String_Vectors.Vector;
      Search   : Files.File_System.Recursive_Search_Result;
      Before   : Files.File_System.Directory_Signature;
      Change   : Files.File_System.Directory_Change_Result;
      Plans    : Files.File_System.Drop_Import_Result;
      Mutation : Files.File_System.Mutation_Result;
      Thumbnail : Files.File_System.Thumbnail_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Source_File : constant String := Join (Root, "drop-source.txt");
      Source_Dir  : constant String := Join (Root, "drop-dir");
      Drop_Target : constant String := Join (Root, "drop-target");
      Delete_Dir  : constant String := Join (Root, "delete-tree");
      Thumbnail_Source : constant String := Join (Root, "picture.png");
      Decoded_Png_Source : constant String := Join (Root, "decoded-picture.png");
      Ppm_Thumbnail_Source : constant String := Join (Root, "picture.ppm");
      Thumbnail_Cache  : constant String := Join (Root, "thumb-cache");
      Cache_Home : constant String := Join (Root, "cache-home");
      Had_Cache  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_CACHE_HOME");
      Old_Cache  : Unbounded_String;

      procedure Restore_Cache is
      begin
         if Had_Cache then
            Ada.Environment_Variables.Set ("XDG_CACHE_HOME", To_String (Old_Cache));
         else
            Ada.Environment_Variables.Clear ("XDG_CACHE_HOME");
         end if;
      end Restore_Cache;
   begin
      if Had_Cache then
         Old_Cache := To_Unbounded_String (Ada.Environment_Variables.Value ("XDG_CACHE_HOME"));
      end if;

      Reset_Root;
      declare
         First_Empty  : constant String := Join (Root, "signature-empty-a");
         Second_Empty : constant String := Join (Root, "signature-empty-b");
      begin
         Ada.Directories.Create_Directory (First_Empty);
         Ada.Directories.Create_Directory (Second_Empty);
         Before := Files.File_System.Directory_State (First_Empty);
         Change := Files.File_System.Detect_Directory_Change
           (Before, Second_Empty);
         Assert
           (Change.Changed
            and then Change.Before_State.Path /= Change.After_State.Path,
            "directory signatures from different empty roots never compare unchanged");
         Ada.Directories.Delete_Directory (First_Empty);
         Ada.Directories.Delete_Directory (Second_Empty);
      end;
      Ada.Directories.Create_Path (Join (Root, "search"));
      Ada.Directories.Create_Path (Join (Join (Root, "search"), "nested"));
      Write_File (Join (Join (Root, "search"), "alpha-match.txt"), "alpha");
      Write_File (Join (Join (Join (Root, "search"), "nested"), "beta-match.txt"), "beta");
      Write_File (Join (Join (Root, "search"), "skip.txt"), "skip");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "MATCH", Settings);
      Assert (Search.Success, "recursive search succeeds");
      Assert (Natural (Search.Items.Length) = 2, "recursive search finds nested matches");
      Assert
        (To_String (Search.Items.Element (1).Name) = "alpha-match.txt",
         "recursive search preserves deterministic parent order");
      Assert
        (To_String (Search.Items.Element (2).Name) = "beta-match.txt",
         "recursive search descends into child directories");

      Search := Files.File_System.Search_Recursive (Join (Root, "search"), "match", Settings, Max_Items => 1);
      Assert (Natural (Search.Items.Length) = 1, "recursive search respects result limits");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is disabled without filter text");
      Files.Model.Set_Filter (Model, "match");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Search_Recursive_Command, Model),
         "recursive search command is enabled with filter text");
      Routed :=
        Files.Controller.Execute_Command (Files.Commands.Search_Recursive_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Search_Recursive_Command,
         "recursive search routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "recursive search command succeeds");
      Assert (Files.Model.Item_Count (Model) = 2, "recursive search command loads nested result items");
      Assert
        (To_String (Files.Model.Visible_Item (Model, 2).Name) = "beta-match.txt",
         "recursive search command exposes nested matches in the model");
      Routed := Files.Controller.Execute_Command (Files.Commands.Refresh_Directory_Command, Model, Settings);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "refresh restores direct listing");
      Assert (Files.Model.Item_Count (Model) = 3, "refresh after recursive search reloads direct children");

      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Write_File (Join (Join (Root, "search"), "new-file.txt"), "new");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "polling directory watcher detects added entries");
      Assert
        (Change.After_State.Entry_Count = Before.Entry_Count + 1,
         "directory watcher reports updated entry count");

      Load := Files.File_System.Load_Directory (Join (Root, "search"), Settings);
      Files.Model.Initialize (Model, Join (Root, "search"), Load.Items, Root);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Join (Root, "search")));
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "unchanged directory watcher refresh succeeds");
      Assert (Files.Model.Item_Count (Model) = 4, "unchanged watcher refresh keeps loaded item count");
      Write_File (Join (Join (Root, "search"), "watched-add.txt"), "watch");
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "changed directory watcher refresh succeeds");
      Assert (Files.Model.Item_Count (Model) = 5, "changed watcher refresh reloads new directory items");
      Before := Files.File_System.Directory_State (Join (Root, "search"));
      Ada.Directories.Delete_File (Join (Join (Root, "search"), "skip.txt"));
      Write_File (Join (Join (Root, "search"), "same-count-replacement.txt"), "replacement");
      Change := Files.File_System.Detect_Directory_Change (Before, Join (Root, "search"));
      Assert (Change.Changed, "directory watcher detects same-count replacement");
      Assert
        (Change.After_State.Entry_Count = Before.Entry_Count,
         "same-count replacement keeps directory entry count stable");
      Assert
        (Change.After_State.Entry_State_Checksum /= Before.Entry_State_Checksum,
         "same-count replacement changes directory entry checksum");
      Files.Model.Set_Directory_Signature (Model, Before);
      Routed.Operation := Files.Operations.Refresh_If_Changed (Model, Settings);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "same-count watcher refresh succeeds");
      Assert
        (Files.Model.Item_Count (Model) = 5,
         "same-count watcher refresh keeps replacement entry count");

      Ada.Directories.Create_Path (Drop_Target);
      Write_File (Source_File, "drop");
      Ada.Directories.Create_Path (Source_Dir);
      Write_File (Join (Source_Dir, "inside.txt"), "inside");
      Sources.Append (To_Unbounded_String (Source_File));
      Sources.Append (To_Unbounded_String (Source_Dir));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target);
      Assert (Plans.Success, "drop import planning accepts valid dropped paths");
      Assert (Natural (Plans.Plans.Length) = 2, "drop import plans every source path");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import copy executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "drop-source.txt")), "drop import copies files");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "drop-dir"), "inside.txt")),
         "drop import copies directories");
      Assert (Ada.Directories.Exists (Source_File), "drop copy preserves source file");

      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Source_File));
      --  Dropping onto a name that already exists now arms the paste conflict
      --  dialog (routed through the engine) instead of silently auto-renaming.
      Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
      Assert (Routed.Operation.Status = Files.Operations.Operation_Success, "controller drop import succeeds");
      Assert
        (Files.Model.Paste_Conflict_Is_Active (Model),
         "a colliding drop arms the conflict dialog instead of auto-renaming");
      Assert
        (Files.Model.Paste_Conflict_Name (Model) = "drop-source.txt",
         "the drop conflict dialog names the colliding item");
      Routed.Operation :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving the drop conflict clears the dialog");
      Assert
        (Ada.Directories.Exists (Join (Drop_Target, "drop-source 2.txt")),
         "renaming the drop conflict writes a collision-safe destination");
      Assert (Files.Model.Item_Count (Model) = 3, "resolved drop import refreshes destination model");

      Ada.Directories.Create_Path (Join (Drop_Target, "nested-target"));
      Write_File (Join (Drop_Target, "drag-source.txt"), "drag");
      Load := Files.File_System.Load_Directory (Drop_Target, Settings);
      Files.Model.Initialize (Model, Drop_Target, Load.Items, Root);
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Drop_Target, "drag-source.txt")));
      --  A drop onto a specific folder row routes through Begin_Paste_To; with
      --  no name collision it executes the move immediately.
      Routed.Operation :=
        Files.Operations.Begin_Paste_To
          (Model          => Model,
           Settings       => Settings,
           Source_Paths   => Sources,
           Destination    => Join (Drop_Target, "nested-target"),
           Mode           => Files.File_System.Drop_Move,
           From_Clipboard => False);
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "item drag import can target a specific directory");
      Assert
        (not Files.Model.Paste_Conflict_Is_Active (Model),
         "a collision-free targeted drop executes without arming the dialog");
      Assert
        (Ada.Directories.Exists (Join (Join (Drop_Target, "nested-target"), "drag-source.txt")),
         "item drag import moves the source into the target directory");
      Assert
        (not Ada.Directories.Exists (Join (Drop_Target, "drag-source.txt")),
         "item drag move removes the source from the current directory");
      Assert (Files.Model.Item_Count (Model) = 4, "item drag import refreshes the source window model");

      Sources.Clear;
      Write_File (Join (Root, "move-source.txt"), "move");
      Sources.Append (To_Unbounded_String (Join (Root, "move-source.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Drop_Target, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "drop import move executes");
      Assert (Ada.Directories.Exists (Join (Drop_Target, "move-source.txt")), "drop move creates destination");
      Assert (not Ada.Directories.Exists (Join (Root, "move-source.txt")), "drop move removes source");

      --  Moving an item into the directory it already lives in is a no-op, but
      --  copying into the same directory still makes a numbered duplicate.
      Sources.Clear;
      Write_File (Join (Root, "stay.txt"), "stay");
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Move);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory move succeeds");
      Assert (Ada.Directories.Exists (Join (Root, "stay.txt")), "same-directory move keeps the file in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory move does not create a numbered duplicate");

      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "stay.txt")));
      Plans := Files.File_System.Plan_Drop_Import (Sources, Root, Files.File_System.Drop_Copy);
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-directory copy succeeds");
      Assert
        (Ada.Directories.Exists (Join (Root, "stay 2.txt")),
         "same-directory copy still creates a numbered duplicate");

      --  A directory cannot be moved or copied into itself or a descendant;
      --  the recursive copy would otherwise recurse without bound.
      Ada.Directories.Create_Path (Join (Join (Root, "tree"), "sub"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Root, "tree")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Move);
      Assert (not Plans.Success,
              "moving a directory into its own subtree is rejected; error was "
              & To_String (Plans.Error_Key));
      Assert
        (To_String (Plans.Error_Key) = "error.drop.into_self",
         "into-self drop reports a deterministic diagnostic");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Join (Root, "tree"), "sub"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into its own subtree is rejected");
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "tree"), Files.File_System.Drop_Copy);
      Assert (not Plans.Success, "copying a directory into itself is rejected");

      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         --  A backslash is an ordinary filename byte on POSIX.  This sibling
         --  starts with the source name but is not inside the source tree.
         Ada.Directories.Create_Path (Join (Root, "tree\peer"));
         Plans :=
           Files.File_System.Plan_Drop_Import
             (Sources, Join (Root, "tree\peer"), Files.File_System.Drop_Copy);
         Assert
           (Plans.Success,
            "a POSIX backslash-name sibling is not mistaken for a descendant");
      end if;

      --  Two sources sharing a simple name from different directories must get
      --  distinct destinations within one batch (no silent overwrite).
      Ada.Directories.Create_Path (Join (Root, "src-a"));
      Ada.Directories.Create_Path (Join (Root, "src-b"));
      Write_File (Join (Join (Root, "src-a"), "dup.txt"), "a");
      Write_File (Join (Join (Root, "src-b"), "dup.txt"), "b");
      Ada.Directories.Create_Path (Join (Root, "dup-dest"));
      Sources.Clear;
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-a"), "dup.txt")));
      Sources.Append (To_Unbounded_String (Join (Join (Root, "src-b"), "dup.txt")));
      Plans :=
        Files.File_System.Plan_Drop_Import
          (Sources, Join (Root, "dup-dest"), Files.File_System.Drop_Copy);
      Assert (Plans.Success, "same-name batch drop plans successfully");
      Assert (Natural (Plans.Plans.Length) = 2, "batch drop plans both sources");
      Assert
        (To_String (Plans.Plans.Element (1).Destination_Path)
           /= To_String (Plans.Plans.Element (2).Destination_Path),
         "same-name sources get distinct destinations within a batch");
      Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
      Assert (Mutation.Success, "same-name batch copy executes");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup.txt")),
         "first same-name file is copied");
      Assert
        (Ada.Directories.Exists (Join (Join (Root, "dup-dest"), "dup 2.txt")),
         "second same-name file gets a distinct name instead of overwriting");

      Ada.Directories.Create_Path (Delete_Dir);
      Write_File (Join (Delete_Dir, "doomed.txt"), "doomed");
      Ada.Directories.Create_Path (Join (Delete_Dir, "nested"));
      Write_File (Join (Join (Delete_Dir, "nested"), "child.txt"), "child");
      Mutation := Files.File_System.Delete_Permanently (Delete_Dir);
      Assert (Mutation.Success, "explicit permanent delete removes a tree");
      Assert (not Ada.Directories.Exists (Delete_Dir), "permanent delete removes the target directory");
      Mutation := Files.File_System.Delete_Permanently ("/");
      Assert (not Mutation.Success, "permanent delete refuses root paths");
      Assert
        (To_String (Mutation.Error_Key) = "error.permanent_delete.refused",
         "permanent delete reports unsafe target diagnostic");

      --  A child/.. spelling names the parent directory. Recursive deletion
      --  through that spelling could erase its contents before rmdir fails.
      declare
         Guard : constant String := Join (Root, "dot-delete-guard");
         Child : constant String := Join (Guard, "child");
         Kept : constant String := Join (Guard, "keep.txt");
         procedure Check_Refusal (Attempt : String) is
         begin
            Mutation := Files.File_System.Delete_Permanently (Attempt);
            Assert (not Mutation.Success
                      and then To_String (Mutation.Error_Key) = "error.permanent_delete.refused",
                    "permanent delete refuses dot and parent path components");
            Assert (Ada.Directories.Exists (Child) and then Ada.Directories.Exists (Kept),
                    "a refused navigation path leaves the parent tree intact");
         end Check_Refusal;
      begin
         Ada.Directories.Create_Path (Child);
         Write_File (Kept, "keep this file");
         Check_Refusal (Child & "/..");
         Check_Refusal (Guard & "/.");
         Check_Refusal (Guard & "/./keep.txt");
         Check_Refusal (Child & "/../keep.txt");
      end;

      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         declare
            Literal_Dotdot : constant String := Join (Root, "literal\..");
         begin
            Write_File (Literal_Dotdot, "ordinary POSIX name");
            Mutation := Files.File_System.Delete_Permanently (Literal_Dotdot);
            Assert
              (Mutation.Success and then not Ada.Directories.Exists (Literal_Dotdot),
               "permanent delete does not treat a POSIX backslash as navigation");
         end;
      end if;

      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         declare
            Tool : constant String := Join (Root, "tool\name");
            Old_Path_Exists : constant Boolean :=
              Ada.Environment_Variables.Exists ("PATH");
            Old_Path : constant String :=
              (if Old_Path_Exists
               then Ada.Environment_Variables.Value ("PATH")
               else "");
            Action : constant Files.Settings.Open_Action :=
              Files.Settings.Make_Action
                ("tool\name", Files.Types.String_Vectors.Empty_Vector);
            Available : Boolean := False;
         begin
            Write_File (Tool, "#!/bin/sh" & ASCII.LF & "exit 0" & ASCII.LF);
            Mutation := Files.File_System.Set_Permissions (Tool, 8#755#);
            if Mutation.Success then
               Ada.Environment_Variables.Set ("PATH", Root);
               Available :=
                 Files.Operations.Open_Action_Executable_Is_Available (Action);
               if Old_Path_Exists then
                  Ada.Environment_Variables.Set ("PATH", Old_Path);
               else
                  Ada.Environment_Variables.Clear ("PATH");
               end if;
               Assert
                 (Available,
                  "a POSIX executable containing a backslash is looked up on PATH");
            end if;
         exception
            when others =>
               if Old_Path_Exists then
                  Ada.Environment_Variables.Set ("PATH", Old_Path);
               else
                  Ada.Environment_Variables.Clear ("PATH");
               end if;
               raise;
         end;
      end if;

      --  Regression: permanent-delete of a symlink to a directory must unlink
      --  the LINK, never follow it and recursively wipe the target's real
      --  contents (the previous Directory_Exists + Delete_Tree path did).
      declare
         Link_Target   : constant String := Join (Root, "sym-del-target");
         Kept_File     : constant String := Join (Link_Target, "precious.txt");
         Dir_Link      : constant String := Join (Root, "sym-del-link");
         Link_Result   : Files.File_System.Mutation_Result;
         Target_Kept   : Boolean := False;
         Content_Kept  : Boolean := False;
         Link_Gone     : Boolean := False;
      begin
         Ada.Directories.Create_Path (Link_Target);
         Write_File (Kept_File, "precious");
         if Files_Suite.Support.Create_Symlink (Link_Target, Dir_Link) then
            Link_Result := Files.File_System.Delete_Permanently (Dir_Link);
            --  Capture before cleanup so a failure cannot leave fixtures behind.
            Target_Kept  := Ada.Directories.Exists (Link_Target);
            Content_Kept := Ada.Directories.Exists (Kept_File);
            Link_Gone    := not Hostkit.Fs.Is_Link (Dir_Link);
            if Hostkit.Fs.Is_Link (Dir_Link) then
               declare
                  Removed : constant Boolean := Hostkit.Fs.Delete_Link (Dir_Link);
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
            end if;
            if Ada.Directories.Exists (Link_Target) then
               Project_Tools.Files.Delete_Tree (Link_Target);
            end if;
            Assert (Link_Result.Success, "permanent delete of a directory symlink succeeds");
            Assert (Link_Gone, "permanent delete removes the symlink itself");
            Assert (Target_Kept, "permanent delete of a symlink does not delete the link target directory");
            Assert (Content_Kept, "permanent delete of a symlink preserves the target's real contents");
         end if;
      end;

      Write_Binary_File (Thumbnail_Source, Minimal_Png_Header (48, 32));
      Thumbnail := Files.File_System.Generate_Thumbnail (Thumbnail_Source, Thumbnail_Cache, Size => 8);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "thumbnail generation succeeds");
      Assert (Thumbnail.Width = 8 and then Thumbnail.Height = 8, "thumbnail reports requested dimensions");
      Assert
        (Ada.Directories.Exists (To_String (Thumbnail.Thumbnail_Path)),
         "thumbnail generation writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "P6"),
         "thumbnail artifact is a binary PPM image");
      if Hostkit.Metadata.Mode_Bits_Are_Native then
         declare
            Available : Boolean := False;
         begin
            Assert
              (Files.File_System.Permission_Bits_Of (Thumbnail_Cache, Available)
                 mod 8#1000# = 8#700# and then Available,
               "thumbnail cache is owner-only");
            Assert
              (Files.File_System.Permission_Bits_Of
                 (To_String (Thumbnail.Thumbnail_Path), Available)
                 mod 8#1000# = 8#600# and then Available,
               "thumbnail artifact is owner-only");
         end;
      end if;
      Assert
        (Project_Tools.Files.File_Contains (To_String (Thumbnail.Thumbnail_Path), "8 8"),
         "thumbnail artifact records requested image dimensions");
      declare
         Oversized : constant Files.File_System.Thumbnail_Result :=
           Files.File_System.Generate_Thumbnail
             (Thumbnail_Source, Thumbnail_Cache, Size => 2_049);
      begin
         Assert
           (Oversized.Status = Files.File_System.Thumbnail_Failed
            and then Length (Oversized.Thumbnail_Path) = 0,
            "oversized public thumbnail requests fail before allocating an image");
      end;
      declare
         Cache_Path : constant String := To_String (Thumbnail.Thumbnail_Path);
         Victim : constant String := Join (Root, "thumbnail-cache-victim");
      begin
         Ada.Directories.Delete_File (Cache_Path);
         Write_File (Victim, "must stay intact");
         if Files_Suite.Support.Create_Symlink (Victim, Cache_Path) then
            Thumbnail := Files.File_System.Generate_Thumbnail
              (Thumbnail_Source, Thumbnail_Cache, Size => 8);
            Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated,
                    "thumbnail generation replaces a cache symlink safely");
            Assert (not Hostkit.Fs.Is_Link (Cache_Path),
                    "thumbnail publication replaces the cache entry, not its target");
            Assert (File_Has_Bytes (Victim, "must stay intact"),
                    "thumbnail generation never truncates a cache symlink target");
            Assert (not Ada.Directories.Exists (Cache_Path & ".tmp")
                      and then not Hostkit.Fs.Is_Link (Cache_Path & ".tmp"),
                    "thumbnail publication leaves no temporary cache file");
         end if;
      end;

      --  Decode a COMPLETE PNG (IHDR + a real IDAT + IEND) through the pure-Ada
      --  fast path. The other cases use an IDAT-less header, so this is the only
      --  test that actually drives inflate + unfilter + pixel decode -- and thus
      --  the heap-backed raster buffer. A solid colour must survive the decode
      --  and downscale, so its distinctive red value appears in the written pixels.
      declare
         Png_W   : constant := 60;
         Png_H   : constant := 60;
         --  A well-formed PNG: signature, then an IHDR chunk (with a CRC slot,
         --  unlike Minimal_Png_Header) declaring 8-bit truecolour, non-interlaced.
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#);
         Ihdr    : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (Png_W)
           & Byte (0) & Byte (0) & Byte (0) & Byte (Png_H)
           & Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
         Raster  : Unbounded_String;
         Png_Src : constant String := Join (Root, "decodable-rgb.png");
         Decoded : Files.File_System.Thumbnail_Result;
      begin
         for Row in 1 .. Png_H loop
            Append (Raster, Byte (0));  -- PNG row filter type 0 (None)
            for Col in 1 .. Png_W loop
               Append (Raster, Byte (173) & Byte (89) & Byte (211));
            end loop;
         end loop;
         Write_Binary_File
           (Png_Src,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("IDAT", Stored_Zlib_Stream (To_String (Raster)))
            & Chunk ("IEND", ""));
         Decoded := Files.File_System.Generate_Thumbnail (Png_Src, Thumbnail_Cache, Size => 8);
         Assert
           (Decoded.Status = Files.File_System.Thumbnail_Generated,
            "a complete PNG decodes through the pure-Ada fast path");
         Assert
           (File_Has_Bytes (To_String (Decoded.Thumbnail_Path), Byte (173) & Byte (89) & Byte (211)),
            "the decoded solid colour survives inflate/unfilter/downscale");
      end;

      declare
         Source : constant String := Join (Root, "png-inflate-overrun.png");
         Pixel  : constant String := Byte (173) & Byte (89) & Byte (211);
         Raster : constant String :=
           Byte (0) & Pixel & Pixel & Byte (0) & Pixel & Pixel;
         Generated : Files.File_System.Thumbnail_Result;
      begin
         --  The IHDR declares exactly fourteen inflated scanline bytes.  The
         --  extra byte used to be silently retained by the one-shot inflater,
         --  which first allocated the entire attacker-controlled expansion.
         Write_Binary_File
           (Source, Minimal_Png_RGB (2, 2, Raster & Byte (99)));
         Generated := Files.File_System.Generate_Thumbnail
           (Source, Thumbnail_Cache, Size => 2);
         Assert
           (Generated.Status = Files.File_System.Thumbnail_Generated,
            "an invalid PNG expansion falls back to a generated thumbnail");
         Assert
           (not File_Has_Bytes
              (To_String (Generated.Thumbnail_Path),
               Pixel & Pixel & Pixel & Pixel),
            "PNG inflate rejects output beyond the declared raster budget");
      end;

      Write_Binary_File
        (Decoded_Png_Source,
         Minimal_Png_RGB
           (2,
            2,
            Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (0) &
            Byte (0) & Byte (0) & Byte (0) & Byte (255) & Byte (255) & Byte (255) & Byte (255)));
      Thumbnail := Files.File_System.Generate_Thumbnail (Decoded_Png_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PNG thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PNG thumbnail preserves source pixel colors");

      declare
         Source : constant String := Join (Root, "transparent-picture.png");
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#)
           & Byte (16#1A#) & Byte (16#0A#);
         Ihdr : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (2)
           & Byte (0) & Byte (0) & Byte (0) & Byte (1)
           & Byte (8) & Byte (6) & Byte (0) & Byte (0) & Byte (0);
         Raster : constant String :=
           Byte (0)
           & Byte (255) & Byte (0) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255) & Byte (255);
         Generated : Files.File_System.Thumbnail_Result;
      begin
         Write_Binary_File
           (Source,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("IDAT", Stored_Zlib_Stream (Raster))
            & Chunk ("IEND", ""));
         Generated := Files.File_System.Generate_Thumbnail
           (Source, Thumbnail_Cache, Size => 2);
         Assert
           (Generated.Status = Files.File_System.Thumbnail_Generated,
            "an RGBA PNG produces a thumbnail");
         Assert
           (File_Has_Bytes
              (To_String (Generated.Thumbnail_Path),
               Byte (255) & Byte (255) & Byte (255)
               & Byte (0) & Byte (0) & Byte (255)
               & Byte (255) & Byte (255) & Byte (255)
               & Byte (0) & Byte (0) & Byte (255))
            and then not File_Has_Bytes
              (To_String (Generated.Thumbnail_Path),
               Byte (255) & Byte (0) & Byte (0)
               & Byte (0) & Byte (0) & Byte (255)
               & Byte (255) & Byte (0) & Byte (0)
               & Byte (0) & Byte (0) & Byte (255)),
            "transparent PNG pixels are composited instead of exposing hidden RGB");
      end;

      declare
         Source : constant String := Join (Root, "transparent-key-picture.png");
         Signature : constant String :=
           Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#)
           & Byte (16#1A#) & Byte (16#0A#);
         Ihdr : constant String :=
           Byte (0) & Byte (0) & Byte (0) & Byte (2)
           & Byte (0) & Byte (0) & Byte (0) & Byte (1)
           & Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
         Transparent_Red : constant String :=
           Byte (0) & Byte (255) & Byte (0) & Byte (0) & Byte (0) & Byte (0);
         Raster : constant String :=
           Byte (0)
           & Byte (255) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255);
         Expected : constant String :=
           Byte (255) & Byte (255) & Byte (255)
           & Byte (0) & Byte (0) & Byte (255)
           & Byte (255) & Byte (255) & Byte (255)
           & Byte (0) & Byte (0) & Byte (255);
         Hidden : constant String :=
           Byte (255) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255)
           & Byte (255) & Byte (0) & Byte (0)
           & Byte (0) & Byte (0) & Byte (255);
         Generated : Files.File_System.Thumbnail_Result;
      begin
         Write_Binary_File
           (Source,
            Signature & Chunk ("IHDR", Ihdr)
            & Chunk ("tRNS", Transparent_Red)
            & Chunk ("IDAT", Stored_Zlib_Stream (Raster))
            & Chunk ("IEND", ""));
         Generated := Files.File_System.Generate_Thumbnail
           (Source, Thumbnail_Cache, Size => 2);
         Assert
           (Generated.Status = Files.File_System.Thumbnail_Generated
            and then File_Has_Bytes
              (To_String (Generated.Thumbnail_Path), Expected)
            and then not File_Has_Bytes
              (To_String (Generated.Thumbnail_Path), Hidden),
            "true-colour PNG tRNS transparency is composited against white");
      end;

      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Load := Files.File_System.Load_Directory (Root, Settings);
      declare
         Found_Auto_Thumbnail : Boolean := False;
         Extension_Settings    : Files.Settings.Settings_Model := Settings;
         Extension_Load        : Files.File_System.Directory_Load_Result;
      begin
         for Item of Load.Items loop
            if To_String (Item.Name) = "decoded-picture.png" then
               Found_Auto_Thumbnail := True;
               Assert (Item.Thumbnail_Available, "directory loading auto-generates image thumbnails");
               Assert (Item.Thumbnail_Width = 64, "auto-generated thumbnail records default width");
               Assert (Item.Thumbnail_Height = 64, "auto-generated thumbnail records default height");
               Assert
                 (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels) = 64 * 64 * 4,
                  "auto-generated thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "auto-thumbnail image item is loaded");

         Files.Settings.Add_Extension_Mapping (Extension_Settings, "webp", "application/octet-stream");
         Write_File (Join (Root, "extension-only.webp"), "not a decoded image");
         Extension_Load := Files.File_System.Load_Directory (Root, Extension_Settings);
         Found_Auto_Thumbnail := False;
         for Item of Extension_Load.Items loop
            if To_String (Item.Name) = "extension-only.webp" then
               Found_Auto_Thumbnail := True;
               Assert
                 (Item.Thumbnail_Available,
                  "directory loading auto-generates thumbnails for image extensions");
               Assert
                 (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels) = 64 * 64 * 4,
                  "image-extension thumbnail loads renderable pixels");
            end if;
         end loop;

         Assert (Found_Auto_Thumbnail, "image-extension thumbnail item is loaded");

         --  The cache key now includes the source revision, but an artifact
         --  written in the old ASCII P3 image format under the current key
         --  must still load. Put one there by hand and read it back.
         declare
            Legacy_Source : constant String := Join (Root, "legacy-cached.png");
            Legacy_Load   : Files.File_System.Directory_Load_Result;
            Found_Legacy  : Boolean := False;
            Ascii_Pixels  : Unbounded_String;
         begin
            Write_Binary_File (Legacy_Source, Minimal_Png_Header (8, 8));
            declare
               Legacy_Cache : constant String :=
                 Files.File_System.Thumbnail_Path_For
                   (Legacy_Source,
                    Files.File_System.Default_Thumbnail_Cache_Directory (Root),
                    64);
            begin
               --  2x2 of red, green, blue, white in the old ASCII form.
               Append (Ascii_Pixels, "P3" & ASCII.LF & "2 2" & ASCII.LF & "255" & ASCII.LF);
               Append (Ascii_Pixels, "255 0 0 0 255 0" & ASCII.LF & "0 0 255 255 255 255" & ASCII.LF);
               Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Legacy_Cache));
               Write_File (Legacy_Cache, To_String (Ascii_Pixels));
            end;

            Legacy_Load := Files.File_System.Load_Directory (Root, Settings);
            for Item of Legacy_Load.Items loop
               if To_String (Item.Name) = "legacy-cached.png" then
                  Found_Legacy := True;
                  Assert
                    (Item.Thumbnail_Available,
                     "a thumbnail cached in the old ASCII format still loads");
                  Assert
                    (Item.Thumbnail_Width = 2 and then Item.Thumbnail_Height = 2,
                     "and reports the dimensions its own header declares");
                  Assert
                    (Files.Shared_Bytes.Length (Item.Thumbnail_Pixels) = 2 * 2 * 4,
                     "and yields renderable pixels");
               end if;
            end loop;

            Assert (Found_Legacy, "the legacy-cached item is listed");
         end;

         declare
            Commented_Source : constant String := Join (Root, "commented-cached.txt");
            Trailing_Source  : constant String := Join (Root, "trailing-cached.txt");
            Commented_Cache  : Unbounded_String;
            Trailing_Cache   : Unbounded_String;
            Cache_Load       : Files.File_System.Directory_Load_Result;
            Found_Commented  : Boolean := False;
            Found_Trailing   : Boolean := False;
         begin
            Write_File (Commented_Source, "not an image");
            Write_File (Trailing_Source, "not an image");
            Commented_Cache := To_Unbounded_String
              (Files.File_System.Thumbnail_Path_For
                 (Commented_Source,
                  Files.File_System.Default_Thumbnail_Cache_Directory (Root),
                  64));
            Trailing_Cache := To_Unbounded_String
              (Files.File_System.Thumbnail_Path_For
                 (Trailing_Source,
                  Files.File_System.Default_Thumbnail_Cache_Directory (Root),
                  64));
            Write_Binary_File
              (To_String (Commented_Cache),
               "P6" & ASCII.LF & "# cached preview" & ASCII.LF
               & "1 # width" & ASCII.LF & "1" & ASCII.LF & "255" & ASCII.LF
               & Byte (10) & Byte (20) & Byte (30));
            Write_Binary_File
              (To_String (Trailing_Cache),
               "P6" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF
               & Byte (10) & Byte (20) & Byte (30) & Byte (40));

            Cache_Load := Files.File_System.Load_Directory (Root, Settings);
            for Item of Cache_Load.Items loop
               if To_String (Item.Name) = "commented-cached.txt" then
                  Found_Commented := True;
                  Assert
                    (Item.Thumbnail_Available
                     and then Item.Thumbnail_Width = 1
                     and then Item.Thumbnail_Height = 1,
                     "a binary cached PPM accepts comments between header fields");
               elsif To_String (Item.Name) = "trailing-cached.txt" then
                  Found_Trailing := True;
                  Assert
                    (not Item.Thumbnail_Available
                     and then Files.Shared_Bytes.Is_Empty (Item.Thumbnail_Pixels),
                     "a binary cached PPM rejects bytes beyond its declared raster");
               end if;
            end loop;
            Assert
              (Found_Commented and then Found_Trailing,
               "the binary cache parser fixtures are listed");
         end;

         --  Cache files are persistent input, not trusted decoded pixels.  In
         --  particular, PPM samples above maxval used to be silently clamped;
         --  reject that corrupt entry for a non-image item so auto-generation
         --  cannot hide the loader result from this regression check.
         declare
            Corrupt_Source : constant String := Join (Root, "corrupt-cached.txt");
            Corrupt_Cache  : Unbounded_String;
            Corrupt_Load   : Files.File_System.Directory_Load_Result;
            Found_Corrupt  : Boolean := False;
         begin
            Write_File (Corrupt_Source, "not an image");
            Corrupt_Cache := To_Unbounded_String
              (Files.File_System.Thumbnail_Path_For
                 (Corrupt_Source,
                  Files.File_System.Default_Thumbnail_Cache_Directory (Root),
                  64));
            Write_File
              (To_String (Corrupt_Cache),
               "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF
               & "256 0 0" & ASCII.LF);

            Corrupt_Load := Files.File_System.Load_Directory (Root, Settings);
            for Item of Corrupt_Load.Items loop
               if To_String (Item.Name) = "corrupt-cached.txt" then
                  Found_Corrupt := True;
                  Assert
                    (not Item.Thumbnail_Available
                     and then Files.Shared_Bytes.Is_Empty (Item.Thumbnail_Pixels),
                     "a cached PPM sample above maxval is rejected");
               end if;
            end loop;
            Assert (Found_Corrupt, "the corrupt-cache fixture is listed");
         end;

         declare
            Revision_Source : constant String := Join (Root, "revision-cached.ppm");
            First_Path, Second_Path : Unbounded_String;
         begin
            Write_File
              (Revision_Source,
               "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF & "255 0 0" & ASCII.LF);
            First_Path := To_Unbounded_String
              (Files.File_System.Thumbnail_Path_For
                 (Revision_Source,
                  Files.File_System.Default_Thumbnail_Cache_Directory (Root), 64));
            --  The edit keeps the size, so only the timestamps tell it apart.
            --  Windows stamps them from a clock that advances in steps of up
            --  to about 16 ms; an edit inside one step is indistinguishable.
            delay 0.05;
            Write_File
              (Revision_Source,
               "P3" & ASCII.LF & "1 1" & ASCII.LF & "255" & ASCII.LF & "0 0 255" & ASCII.LF);
            Second_Path := To_Unbounded_String
              (Files.File_System.Thumbnail_Path_For
                 (Revision_Source,
                  Files.File_System.Default_Thumbnail_Cache_Directory (Root), 64));
            Assert
              (First_Path /= Second_Path,
               "editing an image changes its thumbnail cache key");
         end;
      end;

      declare
         Header : constant String := Minimal_Png_Header (4_097, 1_024);
         Data : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Header'Length));
         Width, Height : Natural;
      begin
         for Index in Header'Range loop
            Data (Ada.Streams.Stream_Element_Offset (Index - Header'First + 1)) :=
              Ada.Streams.Stream_Element (Character'Pos (Header (Index)));
         end loop;
         Assert
           (not Files.File_System.Image_Bytes_Extent (Data, Width, Height)
            and then Width = 0 and then Height = 0,
            "encoded images above the colour-glyph pixel budget are rejected");
         declare
            Decoded : constant Files.File_System.Decoded_Image :=
              Files.File_System.Decode_Image_Bytes (Data);
         begin
            Assert
              (not Decoded.Available and then Decoded.Pixels.Is_Empty,
               "the in-memory decoder rejects oversized dimensions before loading pixels");
         end;
      end;
      Assert
        (Project_Tools.Files.Any_File_Contains ("src", "gdk_pixbuf_loader_new")
         or else Project_Tools.Files.Any_File_Contains ("../src", "gdk_pixbuf_loader_new")
         or else Project_Tools.Files.Any_File_Contains ("../../src", "gdk_pixbuf_loader_new"),
         "JPEG thumbnail decoding is routed through the native image loader binding");

      Write_File
        (Ppm_Thumbnail_Source,
         "P3" & ASCII.LF
         & "# decoded thumbnail fixture" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 0 255 0" & ASCII.LF
         & "0 0 255 255 255 255" & ASCII.LF);
      Thumbnail := Files.File_System.Generate_Thumbnail (Ppm_Thumbnail_Source, Thumbnail_Cache, Size => 2);
      Assert (Thumbnail.Status = Files.File_System.Thumbnail_Generated, "decoded PPM thumbnail succeeds");
      Assert
        (File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (255) & Byte (0) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (255) & Byte (0))
         and then File_Has_Bytes (To_String (Thumbnail.Thumbnail_Path), Byte (0) & Byte (0) & Byte (255)),
         "decoded PPM thumbnail preserves source pixel colors");

      Thumbnail := Files.File_System.Generate_Thumbnail (Join (Root, "missing.png"), Thumbnail_Cache, Size => 8);
      Assert
        (Thumbnail.Status = Files.File_System.Thumbnail_Source_Missing,
         "thumbnail generation reports missing sources");
      Assert
        (To_String (Thumbnail.Error_Key) = "error.thumbnail.source_missing",
         "missing thumbnail source reports localized diagnostic");

      Write_File (Join (Root, "command-delete.txt"), "delete");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-delete.txt");
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Delete_Selected_Permanently_Command, Model),
         "permanent delete command is enabled for selected items");
      Routed :=
        Files.Controller.Execute_Command
          (Files.Commands.Delete_Selected_Permanently_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Delete_Selected_Permanently_Command,
         "permanent delete routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "permanent delete command succeeds");
      Assert
        (not Ada.Directories.Exists (Join (Root, "command-delete.txt")),
         "permanent delete command removes the selected file");

      Write_File
        (Join (Root, "command-thumbnail.ppm"),
         "P3" & ASCII.LF
         & "2 2" & ASCII.LF
         & "255" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF
         & "255 0 0 255 0 0" & ASCII.LF);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "command-thumbnail.ppm");
      Ada.Environment_Variables.Set ("XDG_CACHE_HOME", Cache_Home);
      Routed := Files.Controller.Execute_Command (Files.Commands.Generate_Thumbnails_Command, Model, Settings);
      Assert
        (Routed.Command = Files.Commands.Generate_Thumbnails_Command,
         "thumbnail generation routes through command registry");
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Success,
         "thumbnail command succeeds");
      Assert
        (Ada.Directories.Exists (To_String (Routed.Operation.Path)),
         "thumbnail command writes a cache artifact");
      Assert
        (Project_Tools.Files.File_Contains (To_String (Routed.Operation.Path), "P6"),
         "thumbnail command writes PPM thumbnail content");
      Assert
        (Files.Model.Selected_Item (Model).Thumbnail_Available,
         "thumbnail command refresh exposes generated thumbnail in the model");
      Assert
        (To_String (Files.Model.Selected_Item (Model).Thumbnail_Path) = To_String (Routed.Operation.Path),
         "thumbnail command refresh records the generated thumbnail path");
      Files.Model.Set_View_Mode (Model, Files.Types.Large_Icons);
      declare
         Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands
             (Files.Rendering.Build_Snapshot (Model, Settings),
              Width       => 1000,
              Height      => 800,
              Line_Height => 20);
         Empty_Text : Files.Rendering.Text_Render_Result;
         Thumbnail_Batch : Guikit.Vulkan.Submission_Batch;
         Found_Thumbnail_Command : Boolean := False;
         Found_Thumbnail_Icon    : Boolean := False;
         Thumbnail_Tile          : Natural := 0;
         Icon_Index              : Natural := 0;
      begin
         for Command of Thumbnail_Frame.Icons loop
            if Length (Command.Icon_Id) < 8
              or else Slice (Command.Icon_Id, 1, 8) /= "toolbar-"
            then
               Icon_Index := Icon_Index + 1;
            end if;
            if To_String (Command.Asset_Path) = To_String (Routed.Operation.Path) then
               Found_Thumbnail_Command := True;
               Thumbnail_Tile := Icon_Index - 1;
               if To_String (Command.Icon_Id) = "thumbnail" then
                  Found_Thumbnail_Icon := True;
               end if;
            end if;
         end loop;

         Assert
           (Found_Thumbnail_Command,
            "large-icons item icon command points at the generated thumbnail artifact");
         Assert
           (Found_Thumbnail_Icon,
            "large-icons item icon command uses a thumbnail-specific icon asset");
         Thumbnail_Batch := Guikit.Vulkan.Build_Submission
           (Rectangles         => Thumbnail_Frame.Rectangles,
            Triangles          => Thumbnail_Frame.Triangles,
            Icons              => Thumbnail_Frame.Icons,
            Overlay_Rectangles => Thumbnail_Frame.Overlay_Rectangles,
            Layout             => Thumbnail_Frame.Layout,
            Theme              => Thumbnail_Frame.Theme_Palette,
            Text               => Empty_Text);
         declare
            Pixel_Offset : constant Positive := Positive (Thumbnail_Tile * 64 * 4 + 1);
         begin
            Assert
              (Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset) = 255
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 1) = 0
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 2) = 0
               and then Thumbnail_Batch.Icon_Atlas_Pixels.Element (Pixel_Offset + 3) = 255,
               "vulkan icon atlas rasterizes large-icons cached thumbnail pixels");
         end;
      end;
      for Mode in Files.Types.Small_Icons .. Files.Types.Details loop
         if Mode /= Files.Types.Large_Icons then
            Files.Model.Set_View_Mode (Model, Mode);
            declare
               Non_Thumbnail_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Files.Rendering.Build_Snapshot (Model, Settings),
                    Width       => 1000,
                    Height      => 800,
                    Line_Height => 20);
            begin
               for Command of Non_Thumbnail_Frame.Icons loop
                  Assert
                    (To_String (Command.Icon_Id) /= "thumbnail",
                     "non-large item icon command keeps filetype icon");
                  Assert
                    (Command.Thumbnail_Width = 0
                     and then Command.Thumbnail_Height = 0
                     and then Command.Thumbnail_Pixels.Is_Empty,
                     "non-large item icon command does not carry thumbnail pixels");
               end loop;
            end;
         end if;
      end loop;
      Restore_Cache;
   exception
      when others =>
         Restore_Cache;
         raise;
   end Test_Advanced_Filesystem_Operations;
