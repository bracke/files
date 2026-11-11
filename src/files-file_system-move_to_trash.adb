with Hostkit.Durability;
separate (Files.File_System)
function Move_To_Trash
  (Path          : String;
   Trashed_Path  : out Files.Types.UString;
   Recorded_Path : String := "")
   return Mutation_Result
is
   function Unique_Trash_Name
     (Files_Directory : String;
      Info_Directory  : String;
      Name            : String)
      return String
   is
      --  A leaf holds at most 255 bytes. The freedesktop info file adds
      --  ".trashinfo" to the name, and a clash adds a counter (".2" up to
      --  ".2147483647"). A name with no room for what is added is cut down to
      --  fit -- keeping its extension, never inside a UTF-8 sequence -- or the
      --  item could never be trashed. The info file's Path= keeps the
      --  original, which restore uses. The macOS home trash has no info file,
      --  so there a name is cut only when a counter must be added.
      Info_Room : constant Natural := (if Info_Directory = "" then 0 else 10);

      function Fit (Room : Natural) return String is (Files.Leaf_Names.Fit (Name, Room));

      --  Room for the info file's suffix and the longest counter.
      Base      : constant String :=
        (if Info_Directory = "" then Name else Fit (255 - Info_Room - 11));
      Counter   : Positive := 2;
      Candidate : Unbounded_String := To_Unbounded_String (Base);
   begin
      while Files.Fs_Primitives.Entry_Exists (Hostkit.Fs.Join (Files_Directory, To_String (Candidate)))
        or else (Info_Directory /= ""
                 and then
                   Files.Fs_Primitives.Entry_Exists
                     (Hostkit.Fs.Join (Info_Directory, To_String (Candidate) & ".trashinfo")))
      loop
         declare
            Suffix : constant String := "." & Natural_Text (Counter);
         begin
            Candidate := To_Unbounded_String
              ((if Info_Directory = "" then Fit (255 - Suffix'Length) else Base) & Suffix);
         end;
         exit when Counter = Positive'Last;
         Counter := Counter + 1;
      end loop;

      return To_String (Candidate);
   end Unique_Trash_Name;

   function Trash_Info_Path_Value (Path_Value : String) return String is
      Hex    : constant String := "0123456789ABCDEF";
      Result : Unbounded_String;

      function Is_Unreserved (Value : Character) return Boolean is
      begin
         return (Value >= 'A' and then Value <= 'Z')
           or else (Value >= 'a' and then Value <= 'z')
           or else (Value >= '0' and then Value <= '9')
           or else Value = '-'
           or else Value = '.'
           or else Value = '_'
           or else Value = '~'
           or else Value = '/';
      end Is_Unreserved;
   begin
      for Value of Path_Value loop
         if Is_Unreserved (Value) then
            Append (Result, Value);
         else
            declare
               Code : constant Natural := Character'Pos (Value);
            begin
               Append (Result, '%');
               Append (Result, Hex (Code / 16 + 1));
               Append (Result, Hex (Code mod 16 + 1));
            end;
         end if;
      end loop;

      return To_String (Result);
   end Trash_Info_Path_Value;

   Backend    : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   Macos_Home : constant Boolean := Backend = Trash_Macos_Home;
   --  An item on another volume goes to that volume's own trash: a rename,
   --  not a copy of everything into home.
   Volume     : constant String :=
     --  Only for an item the preflight below accepts: choosing a volume's
     --  trash makes it there, which a refused request must not do.
     (if Backend in Trash_Xdg_Data_Home | Trash_Home_Data and then Move_To_Trash_Preflight (Path).Success
      then Volume_Trash_For (Path)
      else "");
   Base       : constant String := (if Volume /= "" then Volume else Trash_Base_Path);
   --  macOS ~/.Trash stores items at the top level, without the freedesktop
   --  files/info split or .trashinfo sidecars, so Finder recognizes them.
   Files_Dir  : constant String :=
     (if Base = "" then ""
      elsif Macos_Home then Base
      else Hostkit.Fs.Join (Base, "files"));
   Info_Dir   : constant String :=
     (if Base = "" or else Macos_Home then "" else Hostkit.Fs.Join (Base, "info"));
   Name      : Unbounded_String;
   Target    : Unbounded_String;
   Info_Path : Unbounded_String;
   Info_Owned : Boolean := False;

   --  Where the item came from, as its info file says it: absolute for the
   --  home trash, relative to the volume's top for a volume trash.
   function Info_Path_Text return String is
      --  The path as given, made absolute: the item moved is the link, not
      --  what it points at.
      Original : constant String :=
        Files.Fs_Primitives.Absolute_Name (if Recorded_Path = "" then Path else Recorded_Path);
   begin
      if Volume /= "" then
         declare
            Relative : constant String := Relative_To_Top (Original, Volume_Trash_Top (Volume));
         begin
            if Relative /= "" then
               return Relative;
            end if;
         end;
      end if;
      return Original;
   end Info_Path_Text;

   procedure Delete_Info_File_If_Present is
   begin
      if Info_Owned and then Files.Fs_Primitives.Exists (To_String (Info_Path)) then
         Files.Fs_Primitives.Delete_File (To_String (Info_Path));
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
   end Delete_Info_File_If_Present;
begin
   Files.Io_Errors.Reset;
   Trashed_Path := Null_Unbounded_String;
   declare
      Preflight : constant Mutation_Result := Move_To_Trash_Preflight (Path);
   begin
      if not Preflight.Success then
         return Preflight;
      end if;
   end;

   --  Hand the item to the desktop's own trash where the platform has one.
   --  These backends were written and then never called: everything went down
   --  the freedesktop path, so deleting on Windows built a .trashinfo sidecar
   --  in a directory the Recycle Bin knows nothing about.
   --
   --  The shell owns the item afterwards, so there is no path to hand back --
   --  which is also why an undo cannot restore it, and says so.
   if Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
      declare
         Request : constant Native_Trash_Request :=
           (Backend                 => Backend,
            Path                    => To_Unbounded_String (Path),
            Requires_Native_Api     => True,
            Can_Use_Current_Process => True);

         Native : constant Native_Trash_Result := Trash_Natively (Request);
      begin
         if Native.Completed then
            return (Success => True, Error_Key => Null_Unbounded_String);
         end if;

         return
           (Success   => False,
            Error_Key =>
              (if Native.Error_Key = Null_Unbounded_String
               then To_Unbounded_String ("error.trash.failed")
               else Native.Error_Key));
      end;
   end if;

   --  Create only the generic parent with the process umask. The trash root
   --  and both payload directories are owner-only before any name or
   --  metadata is placed in them.
   begin
      Files.Io_Errors.Clear_Os_Error;
      Files.Fs_Primitives.Create_Path (Files.Fs_Primitives.Parent_Directory (Base));
   exception
      when others =>
         Files.Io_Errors.Capture;
         raise;
   end;
   Files.Private_Directories.Ensure (Base);
   if Files_Dir /= Base then
      Files.Private_Directories.Ensure (Files_Dir);
   end if;
   if Info_Dir /= "" then
      Files.Private_Directories.Ensure (Info_Dir);
   end if;

   Name := To_Unbounded_String
     (Unique_Trash_Name (Files_Dir, Info_Dir, Files.Fs_Primitives.Leaf_Text (Path)));
   Target := To_Unbounded_String (Hostkit.Fs.Join (Files_Dir, To_String (Name)));

   if not Macos_Home then
      Info_Path := To_Unbounded_String (Hostkit.Fs.Join (Info_Dir, To_String (Name) & ".trashinfo"));
      declare
         Metadata : constant String :=
           "[Trash Info]" & ASCII.LF
           & "Path=" & Trash_Info_Path_Value (Info_Path_Text)
           & ASCII.LF & "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock) & ASCII.LF;
         --  Created last, so nothing runs between a refusal and Capture.
         Descriptor : GNAT.OS_Lib.File_Descriptor :=
           Hostkit.Regular_Files.Create_New (To_String (Info_Path), 8#666#);
         Written : Integer;
         Next    : Positive := Metadata'First;
         Closed  : Boolean;
      begin
         if Descriptor = GNAT.OS_Lib.Invalid_FD then
            Files.Io_Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
         Info_Owned := True;
         Files.Private_Directories.Make_File_Private (Descriptor);
         while Next <= Metadata'Last loop
            Written := GNAT.OS_Lib.Write (Descriptor, Metadata (Next)'Address, Metadata'Last - Next + 1);
            if Written <= 0 then
               Files.Io_Errors.Capture;
               raise Ada.Directories.Use_Error;
            end if;
            Next := Next + Written;
         end loop;
         GNAT.OS_Lib.Close (Descriptor, Closed);
         Descriptor := GNAT.OS_Lib.Invalid_FD;
         if not Closed then
            Files.Io_Errors.Capture;
            raise Ada.Directories.Use_Error;
         end if;
         --  On the device before the item moves in: a crash must not leave
         --  an item in the trash with an empty info file, which the trash
         --  view could neither list nor restore.
         if Hostkit.Durability."=" (Hostkit.Durability.Sync_File (To_String (Info_Path)), Hostkit.Durability.Failed)
           or else Hostkit.Durability."=" (Hostkit.Durability.Sync_Directory (Info_Dir), Hostkit.Durability.Failed)
         then
            raise Ada.Directories.Use_Error;
         end if;
      exception
         when others =>
            if Descriptor /= GNAT.OS_Lib.Invalid_FD then
               GNAT.OS_Lib.Close (Descriptor);
            end if;
            raise;
      end;
   end if;

   declare
      use type Hostkit.Fs.Move_Outcome;
      Outcome : Hostkit.Fs.Move_Outcome := Hostkit.Fs.Move_Refused;
   begin
      begin
         Outcome := Support.Move_No_Replace_Outcome (Path, To_String (Target));
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
            Outcome := Hostkit.Fs.Move_Refused;
      end;
      if Outcome /= Hostkit.Fs.Moved and then not Support.Copy_May_Replace_Move (Outcome) then
         --  Refused for a reason a copy would meet too: no copy and delete.
         declare
            Failed : constant Mutation_Result :=
              (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.failed"));
         begin
            Delete_Info_File_If_Present;
            return Failed;
         end;
      elsif Outcome /= Hostkit.Fs.Moved then
         --  Cross-device (EXDEV): rename cannot move across filesystems, so
         --  the home trash is on a different mount than the file. Fall back
         --  to copy-then-delete into the trash.
         declare
            Identity, Revision : UString;
            Copy_Kept : Boolean;
            Moved : constant Mutation_Result :=
              Recovery.Move_By_Copy (Path, To_String (Target), "error.trash.failed", Identity, Revision, Copy_Kept);
         begin
            if not Moved.Success then
               --  A copy left in the trash keeps its info file, so it stays
               --  listed and restorable.
               if Copy_Kept then
                  Trashed_Path := Target;
               else
                  Delete_Info_File_If_Present;
               end if;
               return Moved;
            end if;
         end;
      end if;
   end;

   Trashed_Path := Target;
   return (Success => True, Error_Key => Null_Unbounded_String);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      declare
         Failed : constant Mutation_Result :=
           (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.failed"));
      begin
         Delete_Info_File_If_Present;
         return Failed;
      end;
end Move_To_Trash;
