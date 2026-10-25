separate (Files.File_System)
function Move_To_Trash
  (Path          : String;
   Trashed_Path  : out Files.Types.UString;
   Recorded_Path : String := "")
   return Mutation_Result
is
   function Image_No_Space (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Image_No_Space;

   function Unique_Trash_Name
     (Files_Directory : String;
      Info_Directory  : String;
      Name            : String)
      return String
   is
      Counter   : Positive := 2;
      Candidate : Unbounded_String := To_Unbounded_String (Name);
   begin
      while Ada.Directories.Exists (Join_Path (Files_Directory, To_String (Candidate)))
        or else Hostkit.Fs.Is_Link (Join_Path (Files_Directory, To_String (Candidate)))
        or else (Info_Directory /= ""
                 and then
                   (Ada.Directories.Exists (Join_Path (Info_Directory, To_String (Candidate) & ".trashinfo"))
                    or else Hostkit.Fs.Is_Link (Join_Path (Info_Directory, To_String (Candidate) & ".trashinfo"))))
      loop
         Candidate := To_Unbounded_String (Name & "." & Image_No_Space (Counter));
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
   Base       : constant String := Trash_Base_Path;
   --  macOS ~/.Trash stores items at the top level, without the freedesktop
   --  files/info split or .trashinfo sidecars, so Finder recognizes them.
   Files_Dir  : constant String :=
     (if Base = "" then ""
      elsif Macos_Home then Base
      else Join_Path (Base, "files"));
   Info_Dir   : constant String :=
     (if Base = "" or else Macos_Home then "" else Join_Path (Base, "info"));
   Name      : Unbounded_String;
   Target    : Unbounded_String;
   Info_Path : Unbounded_String;
   Info_Owned : Boolean := False;

   procedure Delete_Info_File_If_Present is
   begin
      if Info_Owned and then Ada.Directories.Exists (To_String (Info_Path)) then
         Ada.Directories.Delete_File (To_String (Info_Path));
      end if;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Trash");
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
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Base));
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
     (Unique_Trash_Name (Files_Dir, Info_Dir, Ada.Directories.Simple_Name (Path)));
   Target := To_Unbounded_String (Join_Path (Files_Dir, To_String (Name)));

   if not Macos_Home then
      Info_Path := To_Unbounded_String (Join_Path (Info_Dir, To_String (Name) & ".trashinfo"));
      declare
         use type GNAT.OS_Lib.File_Descriptor;
         Metadata : constant String :=
           "[Trash Info]" & ASCII.LF
           & "Path="
           & Trash_Info_Path_Value
               (GNAT.OS_Lib.Normalize_Pathname
                  ((if Recorded_Path = "" then Path else Recorded_Path), Resolve_Links => False))
           & ASCII.LF & "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock) & ASCII.LF;
         --  Created last, so nothing runs between a refusal and Capture.
         Descriptor : GNAT.OS_Lib.File_Descriptor :=
           GNAT.OS_Lib.Create_New_File (To_String (Info_Path), GNAT.OS_Lib.Binary);
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
         when others =>
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
   when others =>
      declare
         Failed : constant Mutation_Result :=
           (Success => False, Error_Key => Files.Io_Errors.Error_Key ("error.trash.failed"));
      begin
         Delete_Info_File_If_Present;
         return Failed;
      end;
end Move_To_Trash;
