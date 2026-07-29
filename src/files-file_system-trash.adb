with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Text_IO;
with Files.Platform;
with Files_Config;
with Files.Platform.Windows;
with Files.Platform.Macos;
with Files.Platform.Windows.Trash;
with Files.Platform.Macos.Trash;

separate (Files.File_System)
package body Trash is

   use type Ada.Directories.File_Kind;
   function Trash_Base_Path return String;

   function Trash_Backend_For_Base return Trash_Backend;

   function Path_Can_Be_Directory (Path : String) return Boolean;

   function Two_Digit_Text (Value : Natural) return String;

   function Trash_Base_Path return String is
      Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
      Home          : constant String := Safe_Environment_Value ("HOME");
   begin
      if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
         return "";
      elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
         return "";
      end if;

      if Xdg_Data_Home /= "" then
         return Join_Path (Xdg_Data_Home, "Trash");
      elsif Home /= "" then
         if Ada.Directories.Exists (Join_Path (Home, ".Trash")) then
            return Join_Path (Home, ".Trash");
         end if;

         return Join_Path (Join_Path (Join_Path (Home, ".local"), "share"), "Trash");
      end if;

      return "";
   end Trash_Base_Path;

   function Trash_Backend_For_Base return Trash_Backend is
      Xdg_Data_Home : constant String := Safe_Environment_Value ("XDG_DATA_HOME");
      Home          : constant String := Safe_Environment_Value ("HOME");
   begin
      if Environment_Equals ("FILES_TRASH_BACKEND", "windows") then
         return Trash_Windows_Recycle_Bin;
      elsif Environment_Equals ("FILES_TRASH_BACKEND", "macos") then
         return Trash_Macos_Native;
      elsif Files_Config.Alire_Host_OS = "windows"
        and then not Environment_Equals ("FILES_TRASH_BACKEND", "xdg")
      then
         --  Windows has no HOME/XDG trash; use the shell Recycle Bin by default.
         --  "xdg" forces the freedesktop implementation regardless of host, which
         --  is what lets it be exercised on every platform rather than only where
         --  it happens to be the default.
         return Trash_Windows_Recycle_Bin;
      elsif Xdg_Data_Home /= "" then
         return Trash_Xdg_Data_Home;
      elsif Home /= "" then
         if Ada.Directories.Exists (Join_Path (Home, ".Trash")) then
            return Trash_Macos_Home;
         else
            return Trash_Home_Data;
         end if;
      end if;

      return Trash_Unavailable;
   end Trash_Backend_For_Base;

   function Trash_Files_Directory return String is
      Base    : constant String := Trash_Base_Path;
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
   begin
      if Base = "" then
         return "";
      end if;

      case Backend is
         when Trash_Macos_Home =>
            return Base;
         when Trash_Xdg_Data_Home | Trash_Home_Data =>
            return Join_Path (Base, "files");
         when others =>
            return "";
      end case;
   exception
      when others =>
         return "";
   end Trash_Files_Directory;

   function Path_Can_Be_Directory (Path : String) return Boolean is
      Current : Unbounded_String := To_Unbounded_String (Path);
      Parent  : Unbounded_String;
   begin
      if Path = "" then
         return False;
      end if;

      loop
         declare
            Value : constant String := To_String (Current);
         begin
            if Value = "" then
               return False;
            elsif Ada.Directories.Exists (Value) then
               return Ada.Directories.Kind (Value) = Ada.Directories.Directory;
            end if;

            Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (Value));
            if To_String (Parent) = Value then
               return False;
            end if;
            Current := Parent;
         end;
      end loop;
   exception
      when others =>
         return False;
   end Path_Can_Be_Directory;

   function Two_Digit_Text (Value : Natural) return String is
      Clean : constant String := Natural_Text (Value);
   begin
      if Value < 10 then
         return "0" & Clean;
      end if;

      return Clean;
   end Two_Digit_Text;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
   is
      Year      : Ada.Calendar.Year_Number;
      Month     : Ada.Calendar.Month_Number;
      Day       : Ada.Calendar.Day_Number;
      Seconds   : Ada.Calendar.Day_Duration;
      Remaining : Ada.Calendar.Day_Duration;
      Hour      : Natural := 0;
      Minute    : Natural := 0;
      Second    : Natural := 0;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      Remaining := Seconds;

      while Remaining >= 3_600.0 loop
         Hour := Hour + 1;
         Remaining := Remaining - 3_600.0;
      end loop;

      while Remaining >= 60.0 loop
         Minute := Minute + 1;
         Remaining := Remaining - 60.0;
      end loop;

      while Remaining >= 1.0 loop
         Second := Second + 1;
         Remaining := Remaining - 1.0;
      end loop;

      return
        Natural_Text (Natural (Year)) & "-"
        & Two_Digit_Text (Natural (Month)) & "-"
        & Two_Digit_Text (Natural (Day)) & "T"
        & Two_Digit_Text (Hour) & ":"
        & Two_Digit_Text (Minute) & ":"
        & Two_Digit_Text (Second);
   end Trash_Deletion_Date;

   function Trash_Is_Available return Boolean is
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
   begin
      --  The desktop's own trash needs no base directory of ours: the Recycle
      --  Bin and the Finder's trash are simply there. Asking for a base path
      --  would report no trash at all on Windows, and take the whole
      --  move-to-trash command down with it.
      if Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
         return True;
      end if;

      return Path_Can_Be_Directory (Trash_Base_Path);
   end Trash_Is_Available;

   function Trash_Backend_Of_Current_Environment return Trash_Backend is
   begin
      return Trash_Backend_For_Base;
   end Trash_Backend_Of_Current_Environment;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      case Backend is
         when Trash_Windows_Recycle_Bin | Trash_Macos_Native =>
            return
              (Backend             => Backend,
               Native_Platform     => True,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => True,
               Permanent_Delete    => False,
               Native_Diagnostics  => True,
               Multi_Item_Preflight => True);
         when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
            return
              (Backend             => Backend,
               Native_Platform     => False,
               Xdg_Compatible      => Backend /= Trash_Macos_Home,
               Metadata_Sidecar    => True,
               Collision_Safe_Name => True,
               Permanent_Delete    => False,
               Native_Diagnostics  => True,
               Multi_Item_Preflight => True);
         when Trash_Unavailable =>
            return
              (Backend             => Trash_Unavailable,
               Native_Platform     => False,
               Xdg_Compatible      => False,
               Metadata_Sidecar    => False,
               Collision_Safe_Name => False,
               Permanent_Delete    => False,
               Native_Diagnostics  => True,
               Multi_Item_Preflight => True);
      end case;
   end Trash_Capabilities_Of_Current_Environment;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
   is
      Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
   begin
      return
        (Backend                 => Backend,
         Path                    => To_Unbounded_String (Path),
         Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native,
         Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native);
   end Native_Trash_Request_For;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result is
   begin
      case Request.Backend is
         when Trash_Windows_Recycle_Bin =>
            return Files.Platform.Windows.Evaluate_Trash (Request);
         when Trash_Macos_Native =>
            return Files.Platform.Macos.Evaluate_Trash (Request);
         when Trash_Xdg_Data_Home | Trash_Home_Data | Trash_Macos_Home =>
            return
              (Supported        => True,
               Attempted        => False,
               Completed        => False,
               Native_Binding_Available => False,
               Native_Binding_Status => Native_API_Binding_Missing,
               Binding_Unit    => To_Unbounded_String ("Files.File_System.Move_To_Trash"),
               Desktop_Standard => Request.Backend /= Trash_Macos_Home,
               Would_Delete     => False,
               Uses_Recycle_Bin => False,
               Adapter_Name     =>
                 To_Unbounded_String
                   ((if Request.Backend = Trash_Macos_Home then "macos.home_trash" else "xdg.trash")),
               Native_Api_Name  =>
                 To_Unbounded_String
                   ((if Request.Backend = Trash_Macos_Home then "filesystem.rename" else "freedesktop.trash")),
               Operation_Name   => To_Unbounded_String ("move_to_trash"),
               Requires_User_Consent => False,
               Preserves_Metadata    => True,
               Error_Key        => Null_Unbounded_String);
         when Trash_Unavailable =>
            return
              (Supported        => False,
               Attempted        => False,
               Completed        => False,
               Native_Binding_Available => False,
               Native_Binding_Status => Native_API_Binding_Missing,
               Binding_Unit    => To_Unbounded_String ("none"),
               Desktop_Standard => False,
               Would_Delete     => False,
               Uses_Recycle_Bin => False,
               Adapter_Name     => To_Unbounded_String ("none"),
               Native_Api_Name  => To_Unbounded_String ("none"),
               Operation_Name   => To_Unbounded_String ("none"),
               Requires_User_Consent => False,
               Preserves_Metadata    => False,
               Error_Key        => To_Unbounded_String ("error.trash.unavailable"));
      end case;
   end Evaluate_Native_Trash;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
   is
      Evaluation : constant Native_Trash_Result := Evaluate_Native_Trash (Request);
      Mutation   : Mutation_Result;
   begin
      case Request.Backend is
         when Trash_Windows_Recycle_Bin =>
            return Files.Platform.Windows.Move_To_Recycle_Bin (Request);
         when Trash_Macos_Native =>
            return Files.Platform.Macos.Move_To_Trash (Request);
         when others =>
            null;
      end case;

      if not Evaluation.Supported then
         return
           (Supported             => False,
            Attempted             => False,
            Completed             => False,
            Native_Binding_Available => Evaluation.Native_Binding_Available,
            Native_Binding_Status => Evaluation.Native_Binding_Status,
            Binding_Unit          => Evaluation.Binding_Unit,
            Desktop_Standard      => Evaluation.Desktop_Standard,
            Would_Delete          => Evaluation.Would_Delete,
            Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
            Adapter_Name          => Evaluation.Adapter_Name,
            Native_Api_Name       => Evaluation.Native_Api_Name,
            Operation_Name        => Evaluation.Operation_Name,
            Requires_User_Consent => Evaluation.Requires_User_Consent,
            Preserves_Metadata    => Evaluation.Preserves_Metadata,
            Error_Key             => Evaluation.Error_Key);
      end if;

      Mutation := Move_To_Trash (To_String (Request.Path));
      return
        (Supported             => True,
         Attempted             => True,
         Completed             => Mutation.Success,
         Native_Binding_Available => Evaluation.Native_Binding_Available,
         Native_Binding_Status => Evaluation.Native_Binding_Status,
         Binding_Unit          => Evaluation.Binding_Unit,
         Desktop_Standard      => Evaluation.Desktop_Standard,
         Would_Delete          => False,
         Uses_Recycle_Bin      => Evaluation.Uses_Recycle_Bin,
         Adapter_Name          => Evaluation.Adapter_Name,
         Native_Api_Name       => Evaluation.Native_Api_Name,
         Operation_Name        => Evaluation.Operation_Name,
         Requires_User_Consent => Evaluation.Requires_User_Consent,
         Preserves_Metadata    => Evaluation.Preserves_Metadata,
         Error_Key             => Mutation.Error_Key);
   end Execute_Native_Trash;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
   is
      Base : constant String := Trash_Base_Path;

      Uses_Native_Trash : constant Boolean :=
        Trash_Backend_For_Base in Trash_Windows_Recycle_Bin | Trash_Macos_Native;

      function Source_Exists return Boolean is
      begin
         return Path /= "" and then Ada.Directories.Exists (Path);
      exception
         when others =>
            return False;
      end Source_Exists;

      function Normalized_Text (Value : String) return String is
      begin
         if Value = "" then
            return "";
         elsif Ada.Directories.Exists (Value) then
            return Ada.Directories.Full_Name (Value);
         else
            return Value;
         end if;
      exception
         when others =>
            return Value;
      end Normalized_Text;

      function Is_Same_Or_Inside
        (Child  : String;
         Parent : String)
         return Boolean
      is
         Clean_Child  : constant String := Normalized_Text (Child);
         Clean_Parent : constant String := Normalized_Text (Parent);
         Next         : Natural;
      begin
         if Clean_Child = "" or else Clean_Parent = "" then
            return False;
         elsif Clean_Child = Clean_Parent then
            return True;
         elsif Clean_Child'Length <= Clean_Parent'Length then
            return False;
         elsif Clean_Child (Clean_Child'First .. Clean_Child'First + Clean_Parent'Length - 1) /= Clean_Parent then
            return False;
         end if;

         if Clean_Parent (Clean_Parent'Last) = '/'
           or else Clean_Parent (Clean_Parent'Last) = '\'
         then
            return True;
         end if;

         Next := Clean_Child'First + Clean_Parent'Length;
         return Clean_Child (Next) = '/' or else Clean_Child (Next) = '\';
      exception
         when others =>
            return False;
      end Is_Same_Or_Inside;
   begin
      --  The native backends used to be refused here, because nothing called
      --  them: a desktop trash we could not reach was the same as no trash. They
      --  are wired up now, so refusing the platform's own trash before even
      --  looking at the path meant deleting on Windows always failed with
      --  "native unavailable" while the Recycle Bin sat there unused.
      --
      --  A native backend gets the same checks as any other: it still may not
      --  swallow a path that does not exist, or the filesystem root.
      if not Source_Exists then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;

      --  Everything below is about OUR trash directory: that it exists, that we
      --  are not trying to throw it into itself. A native backend has no such
      --  directory -- the Recycle Bin is the shell's, not ours -- so those checks
      --  do not apply to it, and applying them anyway reported "no trash" on the
      --  one platform whose trash is always there.
      if Uses_Native_Trash then
         return (Success => True, Error_Key => Null_Unbounded_String);
      end if;

      if Base = "" then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.unavailable"));
      elsif not Path_Can_Be_Directory (Base) then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.unavailable"));
      elsif Is_Same_Or_Inside (Base, Path)
        or else Is_Same_Or_Inside (Path, Base)
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
      end if;

      return (Success => True, Error_Key => Null_Unbounded_String);
   end Move_To_Trash_Preflight;

   function Move_To_Trash
     (Path         : String;
      Trashed_Path : out Files.Types.UString)
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
           or else (Info_Directory /= ""
                    and then Ada.Directories.Exists
                               (Join_Path (Info_Directory, To_String (Candidate) & ".trashinfo")))
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

      Backend    : constant Trash_Backend := Trash_Backend_For_Base;
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
      File      : Ada.Text_IO.File_Type;

      procedure Delete_Info_File_If_Present is
      begin
         if Ada.Directories.Exists (To_String (Info_Path)) then
            Ada.Directories.Delete_File (To_String (Info_Path));
         end if;
      exception
         when others =>
            null;
      end Delete_Info_File_If_Present;
   begin
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

            Native : constant Native_Trash_Result :=
              (if Backend = Trash_Windows_Recycle_Bin
               then Files.Platform.Windows.Trash.Move (Request)
               else Files.Platform.Macos.Trash.Move (Request));
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

      Ada.Directories.Create_Path (Files_Dir);
      if Info_Dir /= "" then
         Ada.Directories.Create_Path (Info_Dir);
      end if;

      Name := To_Unbounded_String
        (Unique_Trash_Name (Files_Dir, Info_Dir, Ada.Directories.Simple_Name (Path)));
      Target := To_Unbounded_String (Join_Path (Files_Dir, To_String (Name)));
      Trashed_Path := Target;

      if not Macos_Home then
         Info_Path := To_Unbounded_String (Join_Path (Info_Dir, To_String (Name) & ".trashinfo"));
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, To_String (Info_Path));
         Ada.Text_IO.Put_Line (File, "[Trash Info]");
         Ada.Text_IO.Put_Line (File, "Path=" & Trash_Info_Path_Value (Ada.Directories.Full_Name (Path)));
         Ada.Text_IO.Put_Line (File, "DeletionDate=" & Trash_Deletion_Date (Ada.Calendar.Clock));
         Ada.Text_IO.Close (File);
      end if;

      begin
         Ada.Directories.Rename (Path, To_String (Target));
      exception
         when others =>
            --  Cross-device (EXDEV): rename cannot move across filesystems, so
            --  the home trash is on a different mount than the file. Fall back
            --  to copy-then-delete into the trash.
            begin
               Copy_Tree (Path, To_String (Target));
               declare
                  Removed : constant Mutation_Result := Delete_Permanently (Path);
               begin
                  if not Removed.Success then
                     --  The source could not be removed after the copy, so the
                     --  move failed and the source is kept. Roll back the copy we
                     --  just made into the trash -- both payload and sidecar --
                     --  so no orphaned trash entry is left behind.
                     declare
                        Rolled_Back : constant Mutation_Result :=
                          Delete_Permanently (To_String (Target));
                        pragma Unreferenced (Rolled_Back);
                     begin
                        null;
                     end;
                     Delete_Info_File_If_Present;
                     return Removed;
                  end if;
               end;
            exception
               when others =>
                  Delete_Info_File_If_Present;
                  return
                    (Success   => False,
                     Error_Key => To_Unbounded_String ("error.trash.failed"));
            end;
      end;

      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         Delete_Info_File_If_Present;
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.failed"));
   end Move_To_Trash;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
   is
      Ignored : Files.Types.UString;
   begin
      return Move_To_Trash (Path, Ignored);
   end Move_To_Trash;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
   is
      Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
      Base    : constant String := Trash_Base_Path;
   begin
      if not Removed.Success then
         return Removed;
      end if;

      --  Freedesktop backends keep a <base>/info/<name>.trashinfo sidecar next
      --  to the payload; remove it so the emptied entry leaves no orphaned
      --  metadata. Sidecar removal is best-effort and never fails the purge.
      if Base /= "" and then Backend in Trash_Xdg_Data_Home | Trash_Home_Data then
         declare
            Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
            Info_Path : constant String :=
              Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
         begin
            if Ada.Directories.Exists (Info_Path) then
               Ada.Directories.Delete_File (Info_Path);
            end if;
         exception
            when others =>
               null;
         end;
      end if;

      return Removed;
   end Delete_Trashed_Item;

   function Restore_From_Trash
     (Trashed_Path : String)
      return Mutation_Result
   is
      --  Reverse of Move_To_Trash's Trash_Info_Path_Value percent-encoder.
      function Url_Decode (Value : String) return String is
         Result : Unbounded_String;
         Index  : Natural := Value'First;

         function Hex_Value (Item : Character) return Integer is
         begin
            case Item is
               when '0' .. '9' =>
                  return Character'Pos (Item) - Character'Pos ('0');
               when 'A' .. 'F' =>
                  return Character'Pos (Item) - Character'Pos ('A') + 10;
               when 'a' .. 'f' =>
                  return Character'Pos (Item) - Character'Pos ('a') + 10;
               when others =>
                  return -1;
            end case;
         end Hex_Value;
      begin
         while Index <= Value'Last loop
            if Value (Index) = '%' and then Index + 2 <= Value'Last then
               declare
                  High : constant Integer := Hex_Value (Value (Index + 1));
                  Low  : constant Integer := Hex_Value (Value (Index + 2));
               begin
                  if High >= 0 and then Low >= 0 then
                     Append (Result, Character'Val (High * 16 + Low));
                     Index := Index + 3;
                  else
                     Append (Result, Value (Index));
                     Index := Index + 1;
                  end if;
               end;
            else
               Append (Result, Value (Index));
               Index := Index + 1;
            end if;
         end loop;

         return To_String (Result);
      end Url_Decode;

      --  Read and URL-decode the Path= value from a trashinfo sidecar.
      function Read_Original_Path (Info_File_Path : String) return String is
         File   : Ada.Text_IO.File_Type;
         Result : Unbounded_String;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Info_File_Path);
         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
            begin
               if Line'Length >= 5
                 and then Line (Line'First .. Line'First + 4) = "Path="
               then
                  Result := To_Unbounded_String (Url_Decode (Line (Line'First + 5 .. Line'Last)));
                  exit;
               end if;
            end;
         end loop;
         Safe_Close (File);
         return To_String (Result);
      exception
         when others =>
            Safe_Close (File);
            return "";
      end Read_Original_Path;

      Backend   : constant Trash_Backend := Trash_Backend_For_Base;
      Base      : constant String := Trash_Base_Path;
   begin
      if Base = ""
        or else Backend not in Trash_Xdg_Data_Home | Trash_Home_Data
      then
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
      end if;

      declare
         Simple    : constant String := Ada.Directories.Simple_Name (Trashed_Path);
         Info_Path : constant String :=
           Join_Path (Join_Path (Base, "info"), Simple & ".trashinfo");
         Original  : Unbounded_String;
         Parent    : Unbounded_String;
      begin
         if not Ada.Directories.Exists (Info_Path) then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_unavailable"));
         end if;

         Original := To_Unbounded_String (Read_Original_Path (Info_Path));
         if Length (Original) = 0 then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
         end if;

         Parent := To_Unbounded_String (Ada.Directories.Containing_Directory (To_String (Original)));
         if To_String (Parent) = ""
           or else not Ada.Directories.Exists (To_String (Parent))
           or else Ada.Directories.Kind (To_String (Parent)) /= Ada.Directories.Directory
         then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_parent_missing"));
         end if;

         if Ada.Directories.Exists (To_String (Original)) then
            return
              (Success   => False,
               Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
         end if;

         begin
            Ada.Directories.Rename (Trashed_Path, To_String (Original));
         exception
            when others =>
               --  Cross-device (EXDEV): rename cannot move across filesystems,
               --  so fall back to copy-then-delete just like Move_To_Trash.
               begin
                  Copy_Tree (Trashed_Path, To_String (Original));
               exception
                  when others =>
                     return
                       (Success   => False,
                        Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
               end;
               --  The restore itself is done (the copy succeeded); removing the
               --  now-redundant trash copy is best-effort. Reporting failure here
               --  told the user the restore failed when their file is actually
               --  back, and skipped the sidecar cleanup below, leaving a stale
               --  trash entry. At worst we now leave a rare orphaned payload.
               declare
                  Removed : constant Mutation_Result := Delete_Permanently (Trashed_Path);
                  pragma Unreferenced (Removed);
               begin
                  null;
               end;
         end;

         begin
            if Ada.Directories.Exists (Info_Path) then
               Ada.Directories.Delete_File (Info_Path);
            end if;
         exception
            when others =>
               null;
         end;

         return (Success => True, Error_Key => Null_Unbounded_String);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore_From_Trash;

end Trash;
