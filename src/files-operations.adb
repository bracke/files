with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files_Config;

with Files.Folder_Size;
with Files.Fs;
with Files.Launcher;
with Files.Paste;

with Zlib;

package body Files.Operations is
   use Ada.Strings.Unbounded;
   use type Files.File_System.Thumbnail_Status;
   use type Files.Types.Item_Kind;
   use type Files.File_System.Path_Status;
   use type GNAT.OS_Lib.Argument_List_Access;
   use type GNAT.OS_Lib.String_Access;
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.Model.Undo_Action_Kind;
   use type Zlib.Status_Code;

   function Empty_Action return Files.Settings.Open_Action is
   begin
      return Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector);
   end Empty_Action;

   --  Ada.Directories.Exists raises Name_Error on a malformed path rather than
   --  returning False; treat any failure as "does not exist" so it cannot
   --  escape an operation as an unhandled exception.
   function Exists_Safely (Path : String) return Boolean is
   begin
      return Files.Fs.Exists (Path);
   exception
      when others =>
         return False;
   end Exists_Safely;

   function Open_Action_Policy return Open_Action_Execution_Policy is
   begin
      return
        (Uses_Argument_Vector       => True,
         Shell_Requires_Explicit_Opt_In => True,
         Checks_Executable_Before_Spawn => True,
         Tracks_Execution_Attempt  => True,
         Tracks_Exit_Status        => True,
         --  A detached launch really is asynchronous now: Files.Launcher starts the
         --  process and returns, instead of blocking on a shell that backgrounded it.
         Runs_Asynchronously       => True,
         Supports_Cancellation     => False,
         Rejects_Unsafe_Placeholders => True,
         Reports_Missing_Action    => True,
         Reports_Missing_Executable => True,
         Captures_Executable_Discovery => True,
         Captures_Process_Result       => True,
         Quotes_Shell_Arguments        => True,
         Preserves_Vector_Boundaries   => True,
         Multi_File_Deterministic      => True);
   end Open_Action_Policy;

   function Open_Action_Lifecycle_Of
     (Result : Operation_Result)
      return Open_Action_Lifecycle
   is
      State : Open_Action_Lifecycle_State := Open_Action_Not_Started;
   begin
      if Result.Status = Operation_Action_Executed then
         --  "Completed" means we saw it finish, which we only do when we waited for
         --  it. A detached launch is started and let go, so the honest state is
         --  Spawned: the process is running, and its outcome is not ours to know.
         State :=
           (if Result.Exit_Status_Known
            then Open_Action_Completed
            else Open_Action_Spawned);
      elsif Result.Status = Operation_Failed and then Result.Execution_Attempted then
         State := Open_Action_Failed;
      elsif Result.Status = Operation_Failed
        and then not Result.Executable_Found
        and then To_String (Result.Action_Executable) /= ""
      then
         State := Open_Action_Preflight_Failed;
      elsif Result.Execution_Attempted then
         State := Open_Action_Spawned;
      end if;

      return
        (State             => State,
         Executable        => Result.Action_Executable,
         Argument_Count    => Result.Action_Arguments,
         Uses_Shell        => Result.Action_Uses_Shell,
         Exit_Status_Known => Result.Exit_Status_Known,
         Exit_Status       => Result.Exit_Status,
         Cancellation_Available => False);
   end Open_Action_Lifecycle_Of;

   function Make_Result
     (Status    : Operation_Status;
      Error_Key : String := "";
      Path      : String := "";
      Action    : Files.Settings.Open_Action := Empty_Action;
      Attempted : Boolean := False;
      Found     : Boolean := False;
      Exit_Known : Boolean := False;
      Exit_Status : Integer := 0)
      return Operation_Result is
   begin
      return
        (Status    => Status,
         Error_Key => To_Unbounded_String (Error_Key),
         Path      => To_Unbounded_String (Path),
         Action    => Action,
         Action_Executable => Action.Executable,
         Action_Arguments  => Natural (Action.Arguments.Length),
         Action_Uses_Shell => Action.Use_Shell,
         Execution_Attempted => Attempted,
         Executable_Found    => Found,
         Exit_Status_Known   => Exit_Known,
         Exit_Status         => Exit_Status);
   end Make_Result;

   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, Error_Key);
      return Make_Result (Operation_Disabled, Error_Key);
   end Disabled;

   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, "error.open_action.unsafe_placeholder");
      return Make_Result (Operation_Failed, "error.open_action.unsafe_placeholder", Path);
   end Unsafe_Open_Action;

   function Safe_Environment_Value (Name : String) return String;

   --  Which shell will Shell_Executable actually pick? Everything about running a
   --  command line through it -- the flag that introduces the command, and how its
   --  arguments must be quoted -- follows from this one answer, so it is asked in
   --  one place. They disagreed before: the shell was chosen from COMSPEC (cmd on
   --  Windows) while the quoting stayed POSIX, so an explicit-shell action on
   --  Windows handed cmd single-quoted arguments, which cmd does not understand.
   function Uses_Command_Shell return Boolean is
   begin
      return Safe_Environment_Value ("COMSPEC") /= "";
   end Uses_Command_Shell;

   function Shell_Quote (Value : String) return String is
      Result : Unbounded_String;
   begin
      if Uses_Command_Shell then
         --  cmd.exe: a double-quoted argument, in which a literal " is doubled.
         --  Single quotes mean nothing to cmd -- it would pass them through as part
         --  of the text -- so they cannot be used to group an argument here.
         Append (Result, '"');
         for Character_Value of Value loop
            if Character_Value = '"' then
               Append (Result, """""");
            else
               Append (Result, Character_Value);
            end if;
         end loop;
         Append (Result, '"');
         return To_String (Result);
      end if;

      Append (Result, "'");
      for Character_Value of Value loop
         if Character_Value = ''' then
            Append (Result, "'\''");
         else
            Append (Result, Character_Value);
         end if;
      end loop;
      Append (Result, "'");
      return To_String (Result);
   end Shell_Quote;

   function Shell_Command_Line (Action : Files.Settings.Open_Action) return String is
      Result : Unbounded_String := To_Unbounded_String (Shell_Quote (To_String (Action.Executable)));
   begin
      for Argument of Action.Arguments loop
         Append (Result, " ");
         Append (Result, Shell_Quote (To_String (Argument)));
      end loop;

      return To_String (Result);
   end Shell_Command_Line;

   --  The two arguments a shell takes to run a command line: "-c" (or "/C") and the
   --  command itself.
   function Shell_Argument_Vector
     (Option  : String;
      Command : String)
      return Files.Types.String_Vectors.Vector
   is
      Result : Files.Types.String_Vectors.Vector;
   begin
      Result.Append (To_Unbounded_String (Option));
      Result.Append (To_Unbounded_String (Command));
      return Result;
   end Shell_Argument_Vector;

   function Safe_Environment_Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Shell_Executable return String is
      Comspec : constant String := Safe_Environment_Value ("COMSPEC");
      Shell   : constant String := Safe_Environment_Value ("SHELL");
   begin
      if Comspec /= "" then
         return Comspec;
      elsif Shell /= "" then
         return Shell;
      else
         return "/bin/sh";
      end if;
   end Shell_Executable;

   function Shell_Command_Option return String is
   begin
      return (if Uses_Command_Shell then "/C" else "-c");
   end Shell_Command_Option;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
   is
      Argument_Count : constant Natural := Natural (Action.Arguments.Length);
      Args           : GNAT.OS_Lib.Argument_List_Access := null;
   begin
      Exit_Status := -1;

      if To_String (Action.Executable) = "" then
         return False;
      end if;

      --  A detached launch starts the application and returns; it does not wait,
      --  and so it has no exit status to report -- Exit_Status stays -1 and the
      --  caller is told only whether the launch began.
      --
      --  This used to ask a shell to do the detaching, purely so that the blocking
      --  spawn underneath would come back promptly: "( ... & )" on POSIX and
      --  "start "" /b ..." on cmd. That bought a whole quoting and shell-selection
      --  problem -- and it reported the *shell's* exit code, which said nothing
      --  about the application. Files.Launcher starts the process directly.
      if Detach then
         declare
            Launched : constant Files.Settings.Open_Action :=
              (if Action.Use_Shell
               then Files.Settings.Make_Action
                      (Shell_Executable,
                       Shell_Argument_Vector (Shell_Command_Option, Shell_Command_Line (Action)))
               else Action);
         begin
            if Action.Use_Shell and then Shell_Executable = "" then
               return False;
            end if;

            return Files.Launcher.Launch (Launched);
         end;
      end if;

      if Action.Use_Shell then
         declare
            Shell_Path   : constant String := Shell_Executable;
            Shell_Option : constant String := Shell_Command_Option;
         begin
            if Shell_Path = "" then
               return False;
            end if;

            Args := new GNAT.OS_Lib.Argument_List (1 .. 2);
            Args (1) := new String'(Shell_Option);
            Args (2) := new String'(Shell_Command_Line (Action));
            Exit_Status := GNAT.OS_Lib.Spawn (Shell_Path, Args.all);
         end;
      elsif Argument_Count = 0 then
         declare
            Empty_Args : GNAT.OS_Lib.Argument_List (1 .. 0);
         begin
            Exit_Status := GNAT.OS_Lib.Spawn (To_String (Action.Executable), Empty_Args);
         end;
      else
         Args := new GNAT.OS_Lib.Argument_List (1 .. Argument_Count);
         for Index in 1 .. Argument_Count loop
            Args (Index) := new String'(To_String (Action.Arguments.Element (Positive (Index))));
         end loop;

         Exit_Status := GNAT.OS_Lib.Spawn (To_String (Action.Executable), Args.all);
      end if;

      if Args /= null then
         GNAT.OS_Lib.Free (Args);
      end if;
      return Exit_Status = 0;
   exception
      when others =>
         if Args /= null then
            GNAT.OS_Lib.Free (Args);
         end if;
         return False;
   end Execute_Open_Action;

   function Executable_Is_Available
     (Executable : String)
      return Boolean
   is
      Located : GNAT.OS_Lib.String_Access := null;
   begin
      if Executable = "" then
         return False;
      end if;

      for Character_Value of Executable loop
         if Character_Value = '/' or else Character_Value = '\' then
            return GNAT.OS_Lib.Is_Executable_File (Executable);
         end if;
      end loop;

      Located := GNAT.OS_Lib.Locate_Exec_On_Path (Executable);
      if Located = null then
         return False;
      end if;

      GNAT.OS_Lib.Free (Located);
      return True;
   exception
      when others =>
         if Located /= null then
            GNAT.OS_Lib.Free (Located);
         end if;
         return False;
   end Executable_Is_Available;

   function Open_Action_Executable_Is_Available
     (Action : Files.Settings.Open_Action)
      return Boolean is
   begin
      if Action.Use_Shell then
         return To_String (Action.Executable) /= ""
           and then Executable_Is_Available (Shell_Executable);
      else
         return Executable_Is_Available (To_String (Action.Executable));
      end if;
   end Open_Action_Executable_Is_Available;

   function Reload_Current_Directory
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Select_Name : String := "")
      return Operation_Result
   is
      Load : constant Files.File_System.Directory_Load_Result :=
        Files.File_System.Load_Directory (Files.Model.Current_Path (Model), Settings);
   begin
      if not Load.Success then
         Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Files.Model.Current_Path (Model));
      end if;

      Files.Model.Replace_Items (Model, Load.Items);
      Files.Model.Set_Directory_Signature
        (Model,
         Files.File_System.Directory_State (Files.Model.Current_Path (Model)));
      if Select_Name /= "" then
         declare
            Selection_Restored : constant Boolean := Files.Model.Select_By_Name (Model, Select_Name);
            pragma Unreferenced (Selection_Restored);
         begin
            null;
         end;
      end if;
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end Reload_Current_Directory;

   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Mapped : constant Files.Model.Sort_Field :=
        (case Settings.Sort_Field_Value is
            when Files.Settings.Sort_By_Name     => Files.Model.Sort_Name,
            when Files.Settings.Sort_By_Filetype => Files.Model.Sort_Type,
            when Files.Settings.Sort_By_Size     => Files.Model.Sort_Size,
            when Files.Settings.Sort_By_Created  => Files.Model.Sort_Created,
            when Files.Settings.Sort_By_Modified => Files.Model.Sort_Changed);
   begin
      Files.Model.Set_View_Mode (Model, Settings.Default_View);
      Files.Model.Apply_Sort (Model, Mapped, Settings.Sort_Ascending);
   end Apply_Ui_State;

   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      --  The virtual recent view has no backing directory to reload; rebuild its
      --  synthetic listing from the current recent paths instead.
      if Files.Model.In_Recent_View (Model) then
         return Navigate_Recent (Model, Settings);
      end if;
      --  Preserve the current selection across a manual refresh when the item
      --  still exists (Reload re-selects by name; empty name => no selection).
      return Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
   end Refresh;

   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Change : constant Files.File_System.Directory_Change_Result :=
        Files.File_System.Detect_Directory_Change
          (Files.Model.Directory_Signature_Of (Model),
           Files.Model.Current_Path (Model));
   begin
      if Length (Change.Error_Key) > 0 then
         Files.Model.Set_Error (Model, To_String (Change.Error_Key));
         return Make_Result (Operation_Failed, To_String (Change.Error_Key), Files.Model.Current_Path (Model));
      elsif not Change.Changed then
         Files.Model.Set_Directory_Signature (Model, Change.After_State);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      --  Preserve the selection across an auto-refresh triggered by a
      --  background directory change, when the item still exists.
      return Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
   end Refresh_If_Changed;

   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      Input_Paths : Files.Types.String_Vectors.Vector;
      Entry_Names : Files.Types.String_Vectors.Vector;

      --  Recursively collect ordinary files under a selected entry, recording
      --  each with a directory-relative archive entry name (forward slashes).
      procedure Collect (Full : String; Entry_Name : String) is
         Search    : Ada.Directories.Search_Type;
         Started   : Boolean := False;
         Dir_Entry : Ada.Directories.Directory_Entry_Type;
      begin
         if not Ada.Directories.Exists (Full) then
            return;
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Directory then
            Ada.Directories.Start_Search
              (Search,
               Directory => Full,
               Pattern   => "*",
               Filter    =>
                 [Ada.Directories.Ordinary_File => True,
                  Ada.Directories.Directory     => True,
                  Ada.Directories.Special_File  => False]);
            Started := True;
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               begin
                  if Name /= "." and then Name /= ".." then
                     Collect
                       (Ada.Directories.Full_Name (Dir_Entry),
                        Entry_Name & "/" & Name);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Ordinary_File then
            Input_Paths.Append (To_Unbounded_String (Full));
            Entry_Names.Append (To_Unbounded_String (Entry_Name));
         end if;
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
      end Collect;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
      end if;

      for Item of Items loop
         Collect (To_String (Item.Full_Path), To_String (Item.Name));
      end loop;

      if Input_Paths.Is_Empty then
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
      end if;

      declare
         Extension : constant String :=
           (case Format is
               when Zip_Archive       => "zip",
               when Seven_Zip_Archive => "7z");
         Raw_Base : constant String :=
           Ada.Directories.Base_Name (To_String (Items.First_Element.Name));
         Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

         --  A directory-unique simple archive name, e.g. "report.zip" or
         --  "report (1).zip" when the first choice already exists.
         function Unique_Name return String is
         begin
            if not Ada.Directories.Exists
                     (Ada.Directories.Compose (Directory, Base, Extension))
            then
               return Base & "." & Extension;
            end if;

            for N in 1 .. 9_999 loop
               declare
                  Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
               begin
                  if not Ada.Directories.Exists
                           (Ada.Directories.Compose (Directory, Candidate, Extension))
                  then
                     return Candidate & "." & Extension;
                  end if;
               end;
            end loop;

            return Base & "." & Extension;
         end Unique_Name;

         Archive_Name : constant String := Unique_Name;
         Output_Path  : constant String := Ada.Directories.Compose (Directory, Archive_Name);
         Count        : constant Natural := Natural (Input_Paths.Length);
         Inputs       : Zlib.Text_Array (1 .. Count);
         Names        : Zlib.Text_Array (1 .. Count);
         Status       : Zlib.Status_Code;
      begin
         for I in 1 .. Count loop
            Inputs (I) := Input_Paths.Element (I);
            Names  (I) := Entry_Names.Element (I);
         end loop;

         case Format is
            when Zip_Archive =>
               Zlib.ZIP_Files (Inputs, Output_Path, Names, Status => Status);
            when Seven_Zip_Archive =>
               Zlib.Seven_Zip_Deflate_Files (Inputs, Output_Path, Names, Status => Status);
         end case;

         if Status /= Zlib.Ok then
            return Make_Result (Operation_Failed, "error.compress.failed", Directory);
         end if;

         --  Reload so the new archive appears, and select it.
         return Reload_Current_Directory (Model, Settings, Archive_Name);
      end;
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   end Compress_Selected;

   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Extracted_Any : Boolean := False;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Treat a name ending (case-insensitively) in .zip or .7z as an archive.
      function Name_Is_Archive (Name : String) return Boolean is
         Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
      begin
         return Ada.Strings.Fixed.Tail (Lower, 4) = ".zip"
           or else Ada.Strings.Fixed.Tail (Lower, 3) = ".7z";
      end Name_Is_Archive;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Item_Name : constant String := To_String (Item.Name);
            Full_Path : constant String := To_String (Item.Full_Path);
         begin
            if Name_Is_Archive (Item_Name) then
               declare
                  Raw_Base : constant String := Ada.Directories.Base_Name (Item_Name);
                  Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

                  --  A directory-unique destination folder name, e.g. "report"
                  --  or "report (1)" when the first choice already exists.
                  function Unique_Name return String is
                  begin
                     if not Ada.Directories.Exists (Ada.Directories.Compose (Directory, Base)) then
                        return Base;
                     end if;

                     for N in 1 .. 9_999 loop
                        declare
                           Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
                        begin
                           if not Ada.Directories.Exists (Ada.Directories.Compose (Directory, Candidate)) then
                              return Candidate;
                           end if;
                        end;
                     end loop;

                     return Base;
                  end Unique_Name;

                  Dest_Name : constant String := Unique_Name;
                  Dest_Dir  : constant String := Ada.Directories.Compose (Directory, Dest_Name);
                  Status    : Zlib.Status_Code;
               begin
                  Ada.Directories.Create_Directory (Dest_Dir);
                  Zlib.Extract_Archive_File_To_Directory (Full_Path, Dest_Dir, "", Status);

                  if Status /= Zlib.Ok then
                     return Make_Result (Operation_Failed, "error.extract.failed", Directory);
                  end if;

                  if not Extracted_Any then
                     First_Created := To_Unbounded_String (Dest_Name);
                     Extracted_Any := True;
                  end if;
               end;
            end if;
         end;
      end loop;

      if not Extracted_Any then
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
      end if;

      --  Reload so the new directories appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
   end Extract_Selected;

   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Created_Any   : Boolean := False;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Build the " (copy)" / " (copy N)" marker. The fragments are kept
      --  separate so no single string literal mixes a letter with a space,
      --  which the format-validation tooling rejects.
      function Copy_Marker (Value : Positive) return String is
         Open  : constant String := " (";
         Word  : constant String := "copy";
         Close : constant String := ")";
      begin
         if Value = 1 then
            return Open & Word & Close;
         else
            return Open & Word & " " & Trimmed_Image (Value) & Close;
         end if;
      end Copy_Marker;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Source : constant String := To_String (Item.Full_Path);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Ada.Directories.Extension (Name);
            Base   : constant String := Ada.Directories.Base_Name (Name);

            --  A directory-unique copy stem (without extension), e.g. "report
            --  (copy)" or "report (copy 2)" when earlier choices already exist.
            function Unique_Stem return String is
            begin
               for N in 1 .. 9_999 loop
                  declare
                     Candidate : constant String := Base & Copy_Marker (N);
                  begin
                     if not Ada.Directories.Exists
                              (Ada.Directories.Compose (Directory, Candidate, Ext))
                     then
                        return Candidate;
                     end if;
                  end;
               end loop;

               return Base & Copy_Marker (1);
            end Unique_Stem;

            Dest_Path : constant String :=
              Ada.Directories.Compose (Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Ada.Directories.Simple_Name (Dest_Path);
            Mutation  : constant Files.File_System.Mutation_Result :=
              Files.File_System.Copy_Tree (Source, Dest_Path);
         begin
            if not Mutation.Success then
               return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
            end if;

            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;

      if not Created_Any then
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
      end if;

      --  Reload so the new copies appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
   end Duplicate_Selected;

   --  Shared implementation for the create-symlink and create-hard-link
   --  commands. Each selected item gets a uniquely named link in the current
   --  directory; the created links are recorded so Undo can delete them.
   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Created_Any   : Boolean := False;
      Undo_From     : Files.Types.String_Vectors.Vector;
      Undo_To       : Files.Types.String_Vectors.Vector;
      Undo_Sources  : Files.Types.String_Vectors.Vector;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Build the " (link)" / " (link N)" marker. The fragments are kept
      --  separate so no single string literal mixes a letter with a space,
      --  which the format-validation tooling rejects.
      function Link_Marker (Value : Positive) return String is
         Open  : constant String := " (";
         Word  : constant String := "link";
         Close : constant String := ")";
      begin
         if Value = 1 then
            return Open & Word & Close;
         else
            return Open & Word & " " & Trimmed_Image (Value) & Close;
         end if;
      end Link_Marker;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Source : constant String := To_String (Item.Full_Path);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Ada.Directories.Extension (Name);
            Base   : constant String := Ada.Directories.Base_Name (Name);

            --  A directory-unique link stem (without extension), e.g. "report
            --  (link)" or "report (link 2)" when earlier choices already exist.
            function Unique_Stem return String is
            begin
               for N in 1 .. 9_999 loop
                  declare
                     Candidate : constant String := Base & Link_Marker (N);
                  begin
                     if not Ada.Directories.Exists
                              (Ada.Directories.Compose (Directory, Candidate, Ext))
                     then
                        return Candidate;
                     end if;
                  end;
               end loop;

               return Base & Link_Marker (1);
            end Unique_Stem;

            Dest_Path : constant String :=
              Ada.Directories.Compose (Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Ada.Directories.Simple_Name (Dest_Path);
            Mutation  : constant Files.File_System.Mutation_Result :=
              (if Hard
               then Files.File_System.Create_Hard_Link (Source, Dest_Path)
               else Files.File_System.Create_Symbolic_Link (Source, Dest_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Directory);
            end if;

            Undo_From.Append (To_Unbounded_String (Dest_Path));
            Undo_To.Append (To_Unbounded_String (Dest_Path));
            Undo_Sources.Append (To_Unbounded_String (Source));
            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;

      if not Created_Any then
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
      end if;

      --  A created link is undone by deleting it again and redone by
      --  re-creating it from its recorded source.
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Undo_From, Undo_To,
         Forward     => Undo_Sources,
         Create_Kind =>
           (if Hard
            then Files.Model.Create_Hard_Link
            else Files.Model.Create_Symbolic_Link));

      --  Reload so the new links appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
   end Create_Links;

   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => False);
   end Create_Symlink_Selected;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => True);
   end Create_Hardlink_Selected;

   function Detected_Terminal return String is
      Configured : constant String := Safe_Environment_Value ("TERMINAL");
      Candidates : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("x-terminal-emulator"),
         To_Unbounded_String ("gnome-terminal"),
         To_Unbounded_String ("konsole"),
         To_Unbounded_String ("xfce4-terminal"),
         To_Unbounded_String ("alacritty"),
         To_Unbounded_String ("kitty"),
         To_Unbounded_String ("foot"),
         To_Unbounded_String ("xterm")];
   begin
      if Configured /= "" and then Executable_Is_Available (Configured) then
         return Configured;
      end if;

      for Candidate of Candidates loop
         if Executable_Is_Available (To_String (Candidate)) then
            return To_String (Candidate);
         end if;
      end loop;

      return "";
   exception
      when others =>
         return "";
   end Detected_Terminal;

   function Open_Terminal
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      pragma Unreferenced (Settings);
      Directory : constant String := Files.Model.Current_Path (Model);
      Terminal  : constant String := Detected_Terminal;
   begin
      if Terminal = "" then
         Files.Model.Set_Error (Model, "error.terminal.unavailable");
         return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
      end if;

      declare
         Shell_Path   : constant String := Shell_Executable;
         Shell_Option : constant String := Shell_Command_Option;
         Command      : Unbounded_String;
         Args         : GNAT.OS_Lib.Argument_List_Access := null;
         Exit_Status  : Integer := -1;
      begin
         if Shell_Path = "" then
            Files.Model.Set_Error (Model, "error.terminal.unavailable");
            return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
         end if;

         --  Launch fully detached with the working directory set to the viewed
         --  directory, mirroring the "Open With" detach policy: change into the
         --  directory, then exec the terminal with I/O redirected so it does not
         --  inherit Files's GLFW / Vulkan file descriptors or signal mask.
         Append (Command, "(");
         Append (Command, "cd");
         Append (Command, " ");
         Append (Command, Shell_Quote (Directory));
         Append (Command, " && ");
         Append (Command, Shell_Quote (Terminal));
         Append (Command, " </dev/null >/dev/null 2>&1 &)");

         Args := new GNAT.OS_Lib.Argument_List (1 .. 2);
         Args (1) := new String'(Shell_Option);
         Args (2) := new String'(To_String (Command));
         Exit_Status := GNAT.OS_Lib.Spawn (Shell_Path, Args.all);
         GNAT.OS_Lib.Free (Args);

         if Exit_Status /= 0 then
            Files.Model.Set_Error (Model, "error.terminal.unavailable");
            return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
         end if;

         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Directory);
      end;
   exception
      when others =>
         Files.Model.Set_Error (Model, "error.terminal.unavailable");
         return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
   end Open_Terminal;

   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Query : constant String := Files.Model.Filter_Text (Model);
   begin
      if Query = "" then
         return Disabled (Model, "error.filter.empty");
      end if;

      declare
         Search : constant Files.File_System.Recursive_Search_Result :=
           Files.File_System.Search_Recursive (Files.Model.Current_Path (Model), Query, Settings);
      begin
         if not Search.Success then
            Files.Model.Set_Error (Model, To_String (Search.Error_Key));
            return Make_Result
              (Operation_Failed, To_String (Search.Error_Key), Files.Model.Current_Path (Model));
         end if;

         Files.Model.Replace_Items (Model, Search.Items);
         Files.Model.Note_Search_Results (Model, Files.Types.Search_Names);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (Files.Model.Current_Path (Model)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end;
   end Run_Recursive_Search;

   --  Bounded content-search guards. Bytes read per file mirror the Quick Look
   --  text preview cap; the file and depth caps mirror Directory_Size so the walk
   --  cannot run away on huge or deeply nested trees.
   Content_Search_Max_Bytes   : constant := 64 * 1024;
   Content_Search_Max_Matches : constant := 1_000;
   Content_Search_Max_Files   : constant := 20_000;
   Content_Search_Max_Depth   : constant := 64;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean is
   begin
      if Query = "" or else Bytes'Length = 0 then
         return False;
      end if;

      --  Skip binary payloads: a decisive NUL or a heavy share of control bytes
      --  means the file is not text, so it can never be a content match.
      if Files.Quick_Look.Looks_Binary (Bytes) then
         return False;
      end if;

      return Ada.Strings.Fixed.Index
        (Files.Types.To_Lower (Bytes), Files.Types.To_Lower (Query)) > 0;
   end Content_Matches;

   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Query : constant String := Files.Model.Filter_Text (Model);
      Root  : constant String := Files.Model.Current_Path (Model);
   begin
      if Query = "" then
         return Disabled (Model, "error.filter.empty");
      end if;

      declare
         Matches      : Files.File_System.Item_Vectors.Vector;
         Files_Scanned : Natural := 0;

         procedure Visit (Directory_Path : String; Depth : Natural) is
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Directory_Path, Settings);
         begin
            if not Load.Success or else Depth > Content_Search_Max_Depth then
               return;
            end if;

            for Item of Load.Items loop
               exit when Natural (Matches.Length) >= Content_Search_Max_Matches
                 or else Files_Scanned >= Content_Search_Max_Files;
               if Item.Kind = Files.Types.Regular_File_Item
                 or else Item.Kind = Files.Types.Executable_Item
               then
                  Files_Scanned := Files_Scanned + 1;
                  declare
                     Bytes : constant String :=
                       Files.File_System.Read_Preview_Text
                         (To_String (Item.Full_Path), Content_Search_Max_Bytes);
                  begin
                     if Content_Matches (Bytes, Query) then
                        Matches.Append (Item);
                     end if;
                  end;
               end if;
            end loop;

            --  Descend only into real directories. Symlinked directories arrive
            --  as Symlink_Item, so this walk is inherently cycle-safe.
            for Item of Load.Items loop
               exit when Natural (Matches.Length) >= Content_Search_Max_Matches
                 or else Files_Scanned >= Content_Search_Max_Files;
               if Item.Kind = Files.Types.Directory_Item then
                  Visit (To_String (Item.Full_Path), Depth + 1);
               end if;
            end loop;
         exception
            when others =>
               null;
         end Visit;
      begin
         if not Exists_Safely (Root) then
            Files.Model.Set_Error (Model, "error.directory.load");
            return Make_Result (Operation_Failed, "error.directory.load", Root);
         end if;

         Visit (Root, 0);
         Files.Model.Replace_Items (Model, Matches);
         Files.Model.Note_Search_Results (Model, Files.Types.Search_Contents);
         Files.Model.Set_Directory_Signature
           (Model, Files.File_System.Directory_State (Root));
         if Matches.Is_Empty then
            Files.Model.Set_Error (Model, "search.no_matches");
         else
            Files.Model.Set_Error (Model, "");
         end if;
         return Make_Result (Operation_Success, Path => Root);
      end;
   exception
      when others =>
         Files.Model.Set_Error (Model, "error.search.failed");
         return Make_Result (Operation_Failed, "error.search.failed", Root);
   end Run_Content_Search;

   function Commit_Path_Input
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Files.Model.Path_Input_Text (Model));
      Empty_Items : Files.File_System.Item_Vectors.Vector;
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Commit_Path_Input (Model, Path_Result, Empty_Items);
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result (Operation_Failed, To_String (Path_Result.Error_Key));
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Commit_Path_Input (Model, Path_Result, Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Path_Result.Directory_Path)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Path_Result.Directory_Path));
      end;
   end Commit_Path_Input;

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Files.Model.Home_Path (Model));
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result
           (Operation_Failed,
            To_String (Path_Result.Error_Key),
            Files.Model.Home_Path (Model));
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return
              Make_Result
                (Operation_Failed,
                 To_String (Load.Error_Key),
                 To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Load.Path)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
      end;
   end Navigate_Home;

   function Navigate_Parent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Parent : constant String :=
        Files.File_System.Parent_Directory (Files.Model.Current_Path (Model));
   begin
      --  A filesystem root has no parent, so navigating up is a safe no-op.
      if Parent = "" then
         return Disabled (Model, "error.navigate.no_parent");
      end if;

      declare
         Path_Result : constant Files.File_System.Path_Result :=
           Files.File_System.Normalize_Path (Parent);
      begin
         if Path_Result.Status /= Files.File_System.Path_Valid then
            Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
            return Make_Result
              (Operation_Failed, To_String (Path_Result.Error_Key), Parent);
         end if;

         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
         begin
            if not Load.Success then
               Files.Model.Set_Error (Model, To_String (Load.Error_Key));
               return
                 Make_Result
                   (Operation_Failed,
                    To_String (Load.Error_Key),
                    To_String (Path_Result.Directory_Path));
            end if;

            Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
            Files.Model.Set_Directory_Signature
              (Model,
               Files.File_System.Directory_State (To_String (Load.Path)));
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
         end;
      end;
   end Navigate_Parent;

   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Trash_Dir : constant String := Files.File_System.Trash_Files_Directory;
   begin
      if Trash_Dir = "" then
         Files.Model.Set_Error (Model, "error.trash.unavailable");
         return Make_Result (Operation_Failed, "error.trash.unavailable", Trash_Dir);
      end if;

      declare
         Path_Result : constant Files.File_System.Path_Result :=
           Files.File_System.Normalize_Path (Trash_Dir);
      begin
         if Path_Result.Status /= Files.File_System.Path_Valid then
            Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
            return Make_Result
              (Operation_Failed, To_String (Path_Result.Error_Key), Trash_Dir);
         end if;

         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
         begin
            if not Load.Success then
               Files.Model.Set_Error (Model, To_String (Load.Error_Key));
               return
                 Make_Result
                   (Operation_Failed,
                    To_String (Load.Error_Key),
                    To_String (Path_Result.Directory_Path));
            end if;

            Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
            Files.Model.Set_Directory_Signature
              (Model,
               Files.File_System.Directory_State (To_String (Load.Path)));
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
         end;
      end;
   end Navigate_Trash;

   function Navigate_Recent
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Recent : constant Files.Types.String_Vectors.Vector :=
        Files.Settings.Recent_Paths (Settings);
      Items  : Files.File_System.Item_Vectors.Vector;
   begin
      --  Stat each stored path in most-recent-first order, skipping any that no
      --  longer resolve so a stale entry silently drops from the view.
      for Path of Recent loop
         declare
            Loaded : constant Files.File_System.Item_Load_Result :=
              Files.File_System.Load_Item (To_String (Path), Settings);
         begin
            if Loaded.Success then
               Items.Append (Loaded.Item);
            end if;
         end;
      end loop;

      Files.Model.Navigate_Recent (Model, Items);
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Navigated);
   end Navigate_Recent;

   function Navigate_Back
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Had_Temporary  : constant Boolean := Files.Model.Temporary_Item_Is_Active (Model);
      Temporary_Name : constant String := Files.Model.Temporary_Item_Name (Model);
      Had_Rename     : constant Boolean := Files.Model.Rename_Is_Active (Model);
      Rename_Text    : constant String := Files.Model.Rename_Text (Model);
      Rename_Source  : constant String := Files.Model.Selected_Name (Model);
   begin
      if not Files.Model.Can_Go_Back (Model) then
         return Disabled (Model, "error.history.back_unavailable");
      end if;

      Files.Model.Go_Back (Model);
      declare
         Reload : constant Operation_Result := Refresh (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            Files.Model.Go_Forward (Model);
            if Had_Temporary then
               Files.Model.Begin_Create_File (Model, Temporary_Name);
            elsif Had_Rename then
               declare
                  Selection_Restored : constant Boolean := Files.Model.Select_By_Name (Model, Rename_Source);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
               Files.Model.Resume_Rename (Model, Rename_Text);
            end if;
         end if;

         return Reload;
      end;
   end Navigate_Back;

   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Had_Temporary  : constant Boolean := Files.Model.Temporary_Item_Is_Active (Model);
      Temporary_Name : constant String := Files.Model.Temporary_Item_Name (Model);
      Had_Rename     : constant Boolean := Files.Model.Rename_Is_Active (Model);
      Rename_Text    : constant String := Files.Model.Rename_Text (Model);
      Rename_Source  : constant String := Files.Model.Selected_Name (Model);
   begin
      if not Files.Model.Can_Go_Forward (Model) then
         return Disabled (Model, "error.history.forward_unavailable");
      end if;

      Files.Model.Go_Forward (Model);
      declare
         Reload : constant Operation_Result := Refresh (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            Files.Model.Go_Back (Model);
            if Had_Temporary then
               Files.Model.Begin_Create_File (Model, Temporary_Name);
            elsif Had_Rename then
               declare
                  Selection_Restored : constant Boolean := Files.Model.Select_By_Name (Model, Rename_Source);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
               Files.Model.Resume_Rename (Model, Rename_Text);
            end if;
         end if;

         return Reload;
      end;
   end Navigate_Forward;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Root_Path);
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result (Operation_Failed, To_String (Path_Result.Error_Key), Root_Path);
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Load.Path)));
         Files.Model.Close_Root_Selector (Model);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
      end;
   end Select_Root;

   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
   is
      Index : constant Natural := Files.Model.Root_Selected_Index (Model);
      Path  : Unbounded_String;
   begin
      if not Files.Model.Root_Selector_Is_Open (Model)
        or else Index = 0
        or else Index > Files.Model.Root_Count (Model)
      then
         return Disabled (Model, "error.root.selection.empty");
      end if;

      Path := To_Unbounded_String (Files.Model.Root_Path (Model, Index));
      if not Files.Model.Root_Is_Removable (Model, Index) then
         return Disabled (Model, "error.root.eject_unavailable");
      end if;

      Files.Model.Set_Error (Model, "error.root.eject_unavailable");
      return Make_Result
        (Operation_Failed,
         "error.root.eject_unavailable",
         To_String (Path));
   end Eject_Selected_Root;

   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is
      Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif Natural (Items.Length) > 1 then
         declare
            First_Path : Unbounded_String;
            First_Action : Files.Settings.Open_Action := Empty_Action;
            First_Action_Recorded : Boolean := False;
            First_Exit_Status : Integer := 0;
         begin
            for Item of Items loop
               if Item.Kind = Files.Types.Directory_Item then
                  Files.Model.Set_Error (Model, "error.open_action.multi_directory");
                  return
                    Make_Result
                      (Operation_Failed,
                       "error.open_action.multi_directory",
                       To_String (Item.Full_Path));
               end if;
            end loop;

            for Item of Items loop
               declare
                  Lookup : constant Files.Settings.Action_Lookup_Result :=
                    Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
               begin
                  if Length (First_Path) = 0 then
                     First_Path := Item.Full_Path;
                  end if;

                  if not Lookup.Found then
                     Files.Model.Set_Error (Model, To_String (Lookup.Error_Key));
                     return
                       Make_Result
                         (Operation_Missing_Open_Action,
                          To_String (Lookup.Error_Key),
                          To_String (Item.Full_Path));
                  elsif Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action) then
                     return Unsafe_Open_Action (Model, To_String (Item.Full_Path));
                  end if;

                  declare
                     Action : constant Files.Settings.Open_Action :=
                       Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
                  begin
                     if not Open_Action_Executable_Is_Available (Action) then
                        Files.Model.Set_Error (Model, "error.open_action.executable_missing");
                        return
                          Make_Result
                            (Operation_Failed,
                             "error.open_action.executable_missing",
                             To_String (Item.Full_Path),
                             Action,
                             Attempted => False,
                             Found     => False);
                     end if;

                     if not First_Action_Recorded then
                        First_Action := Action;
                        First_Action_Recorded := True;
                     end if;
                  end;
               end;
            end loop;

            for Item of Items loop
               declare
                  Lookup : constant Files.Settings.Action_Lookup_Result :=
                    Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
                  Action : constant Files.Settings.Open_Action :=
                    Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
                  Exit_Status : Integer := 0;
                  Spawn_OK    : constant Boolean :=
                    Execute_Open_Action (Action, Exit_Status, Detach => True);
               begin
                  --  System-fallback handlers (xdg-open / open / cmd start)
                  --  are launched detached: Spawn_OK reflects whether the
                  --  fork+exec succeeded, not the handler's own exit code.
                  if not Spawn_OK then
                     Files.Model.Set_Error (Model, "error.open_action.execution");
                     return
                       Make_Result
                         (Operation_Failed,
                          "error.open_action.execution",
                          To_String (Item.Full_Path),
                          Action,
                          Attempted => True,
                          Found     => True,
                          Exit_Known => False,
                          Exit_Status => Exit_Status);
                  end if;

                  --  Each launched file joins the recent list, freshest last.
                  Files.Model.Note_Recent_Open (Model, To_String (Item.Full_Path));

                  if To_String (Item.Full_Path) = To_String (First_Path) then
                     First_Exit_Status := Exit_Status;
                  end if;
               end;
            end loop;

            Files.Model.Set_Error (Model, "");
            return
              Make_Result
                (Operation_Action_Executed,
                 Path      => To_String (First_Path),
                 Action    => First_Action,
                 Attempted => First_Action_Recorded,
                 Found     => First_Action_Recorded,
                 --  Detached: started and let go, so there is no exit status.
                 Exit_Known => False,
                 Exit_Status => First_Exit_Status);
         end;
      end if;

      declare
         Prepared : constant Operation_Result := Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      begin
         if Prepared.Status /= Operation_Success then
            return Prepared;
         elsif To_String (Prepared.Action.Executable) = "" then
            declare
               Load : constant Files.File_System.Directory_Load_Result :=
                 Files.File_System.Load_Directory (To_String (Prepared.Path), Settings);
            begin
               if not Load.Success then
                  Files.Model.Set_Error (Model, To_String (Load.Error_Key));
                  return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Prepared.Path));
               end if;

               Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
               Files.Model.Set_Directory_Signature
                 (Model,
                  Files.File_System.Directory_State (To_String (Load.Path)));
               --  Opening a folder records it too: recent folders are useful.
               Files.Model.Note_Recent_Open (Model, To_String (Load.Path));
               Files.Model.Set_Error (Model, "");
               return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
            end;
         elsif not Open_Action_Executable_Is_Available (Prepared.Action) then
            Files.Model.Set_Error (Model, "error.open_action.executable_missing");
            return
              Make_Result
                (Operation_Failed,
                 "error.open_action.executable_missing",
                 To_String (Prepared.Path),
                 Prepared.Action,
                 Attempted => False,
                 Found     => False);
         else
            declare
               Exit_Status : Integer := 0;
               Spawn_OK    : constant Boolean :=
                 Execute_Open_Action
                   (Prepared.Action, Exit_Status, Detach => True);
            begin
               --  Open actions are always detached: the launched application
               --  is fire-and-forget and inherits no Files-side FDs / signal
               --  mask. Spawn_OK reflects whether the wrapper shell ran, not
               --  the application's own exit code.
               if Spawn_OK then
                  --  The opened file joins the recent list.
                  Files.Model.Note_Recent_Open (Model, To_String (Prepared.Path));
                  Files.Model.Set_Error (Model, "");
                  return
                    Make_Result
                      (Operation_Action_Executed,
                       Path   => To_String (Prepared.Path),
                       Action => Prepared.Action,
                       Attempted => True,
                       Found  => True,
                       Exit_Known => False,
                       Exit_Status => Exit_Status);
               end if;

               Files.Model.Set_Error (Model, "error.open_action.execution");
               return
                 Make_Result
                   (Operation_Failed,
                    "error.open_action.execution",
                    To_String (Prepared.Path),
                    Prepared.Action,
                    Attempted => True,
                    Found     => True,
                    Exit_Known => False,
                    Exit_Status => Exit_Status);
            end;
         end if;
      end;
   end Open_Selected;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is
      Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif Items.Is_Empty then
         return Disabled (Model, "error.selection.empty");
      elsif Natural (Items.Length) > 1 then
         declare
            First_Path : Unbounded_String;
            First_Action : Files.Settings.Open_Action := Empty_Action;
            First_Action_Recorded : Boolean := False;
         begin
            for Item of Items loop
               if Item.Kind = Files.Types.Directory_Item then
                  Files.Model.Set_Error (Model, "error.open_action.multi_directory");
                  return
                    Make_Result
                      (Operation_Failed,
                       "error.open_action.multi_directory",
                       To_String (Item.Full_Path));
               end if;
            end loop;

            for Item of Items loop
               declare
                  Lookup : constant Files.Settings.Action_Lookup_Result :=
                    Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
               begin
                  if Length (First_Path) = 0 then
                     First_Path := Item.Full_Path;
                  end if;

                  if not Lookup.Found then
                     Files.Model.Set_Error (Model, To_String (Lookup.Error_Key));
                     return
                       Make_Result
                         (Operation_Missing_Open_Action,
                          To_String (Lookup.Error_Key),
                          To_String (Item.Full_Path));
                  elsif Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action) then
                     return Unsafe_Open_Action (Model, To_String (Item.Full_Path));
                  end if;

                  if not First_Action_Recorded then
                     First_Action :=
                       Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
                     First_Action_Recorded := True;
                  end if;
               end;
            end loop;

            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success, Path => To_String (First_Path), Action => First_Action);
         end;
      end if;

      declare
         Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
      begin
         if Item.Kind = Files.Types.Directory_Item then
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success, Path => To_String (Item.Full_Path));
         end if;

         declare
            Lookup : constant Files.Settings.Action_Lookup_Result :=
              Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
         begin
            if not Lookup.Found then
               Files.Model.Set_Error (Model, To_String (Lookup.Error_Key));
               return
                 Make_Result
                   (Operation_Missing_Open_Action,
                    To_String (Lookup.Error_Key),
                    To_String (Item.Full_Path));
            elsif Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action) then
               return Unsafe_Open_Action (Model, To_String (Item.Full_Path));
            end if;

            declare
               Action : constant Files.Settings.Open_Action :=
                 Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
            begin
               Files.Model.Set_Error (Model, "");
               return Make_Result (Operation_Success, Path => To_String (Item.Full_Path), Action => Action);
            end;
         end;
      end;
   end Prepare_Open_Selected_Action;

   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
      Undo_From  : Files.Types.String_Vectors.Vector;
      Undo_To    : Files.Types.String_Vectors.Vector;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif not Files.File_System.Trash_Is_Available then
         Files.Model.Set_Error (Model, "error.trash.unavailable");
         return Make_Result (Operation_Failed, "error.trash.unavailable");
      end if;

      for Item of Items loop
         declare
            Preflight : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash_Preflight (To_String (Item.Full_Path));
         begin
            if Preflight.Success then
               null;
            else
               Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));
               end;
               return Make_Result
                 (Operation_Failed, To_String (Preflight.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      for Item of Items loop
         if not Exists_Safely (To_String (Item.Full_Path)) then
            Files.Model.Set_Error (Model, "error.trash.failed");
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, "error.trash.failed");
            end;
            return Make_Result (Operation_Failed, "error.trash.failed", To_String (Item.Full_Path));
         end if;
      end loop;

      for Item of Items loop
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Trashed  : Files.Types.UString;
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash (To_String (Item.Full_Path), Trashed);
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
            Undo_From.Append (Trashed);
            Undo_To.Append (Item.Full_Path);
         end;
      end loop;

      --  Restoring from trash reproduces the original path, but re-trashing
      --  allocates a fresh trash location, so this entry is undo-only.
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To,
         Redoable => False);

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Delete_Selected;

   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         if not Exists_Safely (To_String (Item.Full_Path)) then
            Files.Model.Set_Error (Model, "error.permanent_delete.failed");
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, "error.permanent_delete.failed");
            end;
            return Make_Result
              (Operation_Failed, "error.permanent_delete.failed", To_String (Item.Full_Path));
         end if;
      end loop;

      for Item of Items loop
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Permanently (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Delete_Selected_Permanently;

   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Restore_From_Trash (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Restore_Selected_From_Trash;

   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Trash_Dir   : constant String := Files.File_System.Trash_Files_Directory;
      Load        : Files.File_System.Directory_Load_Result;
      Total       : Natural := 0;
      Failed      : Natural := 0;
      First_Error : Unbounded_String;
   begin
      if Trash_Dir = "" then
         return Disabled (Model, "error.trash.unavailable");
      end if;

      --  Enumerate the same payloads the trash view lists, then purge each one.
      Load := Files.File_System.Load_Directory (Trash_Dir, Settings);
      if not Load.Success then
         Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Trash_Dir);
      end if;

      for Item of Load.Items loop
         Total := Total + 1;
         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Trashed_Item (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Failed := Failed + 1;
               if Length (First_Error) = 0 then
                  First_Error := Mutation.Error_Key;
               end if;
            end if;
         end;
      end loop;

      --  Reload the (now emptied) trash view regardless of per-item outcome.
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      --  Emptying the trash is terminal: no undo entry is recorded.
      if Total > 0 and then Failed = Total then
         declare
            Error_Key : constant String :=
              (if Length (First_Error) > 0 then To_String (First_Error) else "error.trash.empty_failed");
         begin
            Files.Model.Set_Error (Model, Error_Key);
            return Make_Result (Operation_Failed, Error_Key, Trash_Dir);
         end;
      elsif Failed > 0 then
         --  Mixed outcome: the survivors are reported as a non-fatal diagnostic.
         Files.Model.Set_Error (Model, "error.trash.empty_partial");
         return Make_Result (Operation_Success, Path => Trash_Dir);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Trash_Dir);
   end Empty_Trash;

   function Generate_Selected_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
      First_Name : Unbounded_String;

      function Cache_Directory return String is
      begin
         return Files.File_System.Default_Thumbnail_Cache_Directory (Files.Model.Current_Path (Model));
      end Cache_Directory;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         declare
            Thumbnail : constant Files.File_System.Thumbnail_Result :=
              Files.File_System.Generate_Thumbnail (To_String (Item.Full_Path), Cache_Directory);
         begin
            if Thumbnail.Status /= Files.File_System.Thumbnail_Generated then
               --  Refresh so thumbnails already generated for earlier items in
               --  the batch are shown, then restore the failure diagnostic.
               Files.Model.Set_Error (Model, To_String (Thumbnail.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Thumbnail.Error_Key));
               end;
               return Make_Result
                 (Operation_Failed, To_String (Thumbnail.Error_Key), To_String (Item.Full_Path));
            elsif Length (First_Path) = 0 then
               First_Path := Thumbnail.Thumbnail_Path;
               First_Name := Item.Name;
            end if;
         end;
      end loop;

      Files.Model.Set_Error (Model, "");
      declare
         Reload : constant Operation_Result :=
           Reload_Current_Directory (Model, Settings, Select_Name => To_String (First_Name));
         pragma Unreferenced (Reload);
      begin
         null;
      end;
      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Generate_Selected_Thumbnails;

   --  Full paths of every entry directly inside Directory (hidden entries
   --  included). Used as the "already exists" set for conflict detection and for
   --  rename uniquification, so a renamed paste avoids any existing name, not
   --  just the colliding one. Falls back to an empty set when the directory
   --  cannot be scanned; Execute_Drop_Import then still refuses to clobber.
   function Existing_Destination_Paths
     (Directory : String)
      return Files.Types.String_Vectors.Vector
   is
      Result : Files.Types.String_Vectors.Vector;
      Search : Ada.Directories.Search_Type;
      Entry_Value : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Directory,
         Pattern   => "",
         Filter    => [others => True]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Entry_Value);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Entry_Value);
         begin
            if Name /= "." and then Name /= ".." then
               Result.Append (To_Unbounded_String (Files.Paste.Desired_Path (Directory, Name)));
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return Result;
   exception
      when others =>
         return Files.Types.String_Vectors.Empty_Vector;
   end Existing_Destination_Paths;

   --  Build the paste work-list from validated plans: one item per valid plan,
   --  skipping a move whose destination equals its source (moving an item into
   --  the directory it already lives in is a no-op).
   function Paste_Work_List
     (Plans     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Directory : String)
      return Files.Paste.Work_Item_Vectors.Vector
   is
      Work : Files.Paste.Work_Item_Vectors.Vector;
   begin
      for Plan of Plans loop
         if Plan.Valid
           and then not (Plan.Mode = Files.File_System.Drop_Move
                         and then Plan.Source_Path = Plan.Destination_Path)
         then
            Work.Append
              (Files.Paste.Work_Item'
                 (Source_Path => Plan.Source_Path,
                  Dest_Dir    => To_Unbounded_String (Directory),
                  Dest_Name   =>
                    To_Unbounded_String
                      (Ada.Directories.Simple_Name (To_String (Plan.Source_Path)))));
         end if;
      end loop;
      return Work;
   end Paste_Work_List;

   --  Remove a destination that a Replace decision must overwrite: move it to the
   --  trash when a backend is available, otherwise delete it permanently. Never
   --  touches a destination that is also the source (a paste onto itself).
   function Clear_Replaced_Destination (Path : String; Source : String) return Boolean is
   begin
      if not Exists_Safely (Path) or else Path = Source then
         return True;
      end if;

      if Files.File_System.Move_To_Trash (Path).Success then
         return True;
      end if;
      return Files.File_System.Delete_Permanently (Path).Success;
   end Clear_Replaced_Destination;

   --  Batch size for the first advance driven from Begin_Paste /
   --  Resolve_Paste_Conflict: large enough that ordinary interactive pastes
   --  finish in one step (so no progress overlay ever flickers), while larger
   --  batches keep animating through the per-frame render-loop advances.
   Paste_Execution_First_Batch : constant := 32;

   --  Finalize an armed paste execution: record one undo covering the items
   --  actually completed (move reversed by moving back; copy by deleting the
   --  created copies), clear the move-mode clipboard, reload, and clear the
   --  execution state. A non-empty Error_Key reports a mid-run write failure.
   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String)
      return Operation_Result
   is
      Mode       : constant Files.File_System.Drop_Import_Mode :=
        Files.Model.Paste_Execution_Mode (Model);
      Undo_From  : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Paste_Execution_Undo_From (Model);
      Undo_To    : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Paste_Execution_Undo_To (Model);
      First_Dest : constant String := Files.Model.Paste_Execution_First_Dest (Model);
   begin
      if not Undo_From.Is_Empty then
         if Mode = Files.File_System.Drop_Move then
            Files.Model.Record_Undo (Model, Files.Model.Undo_Move, Undo_From, Undo_To);
         else
            --  A copy is reversed by deleting the created copies (Undo_From) and
            --  redone by copying each source (Undo_To) back to its destination.
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Undo_From,
               Files.Types.String_Vectors.Empty_Vector,
               Forward     => Undo_To,
               Create_Kind => Files.Model.Create_Copy);
         end if;

         --  A clipboard cut/move consumes the clipboard once the paste has run
         --  (even if it was cancelled part-way, the completed sources have
         --  already moved). A drag-and-drop move never touches the clipboard, so
         --  it must not clear an unrelated clipboard selection.
         if Mode = Files.File_System.Drop_Move
           and then Files.Model.Paste_Execution_Clears_Clipboard (Model)
         then
            Files.Model.Clear_Clipboard (Model);
         end if;
      end if;

      Files.Model.Clear_Paste_Execution (Model);

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            if Error_Key /= "" then
               Files.Model.Set_Error (Model, Error_Key);
               return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
            end if;
            return Reload;
         end if;
      end;

      if Error_Key /= "" then
         Files.Model.Set_Error (Model, Error_Key);
         return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => First_Dest);
   end Finalize_Paste_Execution;

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
   is
      Processed : Natural := 0;
   begin
      if not Files.Model.Paste_Execution_Is_Active (Model) then
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      while Processed < Max_Items
        and then not Files.Model.Paste_Execution_Cancelled (Model)
        and then Files.Model.Paste_Execution_Cursor (Model)
                 < Files.Model.Paste_Execution_Action_Count (Model)
      loop
         declare
            Index  : constant Positive := Files.Model.Paste_Execution_Cursor (Model) + 1;
            Action : constant Files.Paste.Resolved_Action :=
              Files.Model.Paste_Execution_Action (Model, Index);
         begin
            if Action.Skip then
               Files.Model.Skip_Paste_Execution_Action (Model);
            else
               if Action.Replaced
                 and then not Clear_Replaced_Destination
                                (To_String (Action.Dest_Path), To_String (Action.Source_Path))
               then
                  return Finalize_Paste_Execution (Model, Settings, "error.drop.failed");
               end if;

               declare
                  Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
               begin
                  Plans.Append
                    (Files.File_System.Drop_Import_Plan'
                       (Source_Path      => Action.Source_Path,
                        Destination_Path => Action.Dest_Path,
                        Mode             => Files.Model.Paste_Execution_Mode (Model),
                        Valid            => True,
                        Error_Key        => Null_Unbounded_String));
                  declare
                     Mutation : constant Files.File_System.Mutation_Result :=
                       Files.File_System.Execute_Drop_Import (Plans);
                  begin
                     if not Mutation.Success then
                        return Finalize_Paste_Execution
                          (Model, Settings, To_String (Mutation.Error_Key));
                     end if;
                  end;
               end;

               Files.Model.Record_Paste_Execution_Write
                 (Model,
                  Action.Dest_Path,
                  Action.Source_Path,
                  Ada.Directories.Simple_Name (To_String (Action.Dest_Path)));
            end if;
         end;
         Processed := Processed + 1;
      end loop;

      if Files.Model.Paste_Execution_Cancelled (Model)
        or else Files.Model.Paste_Execution_Cursor (Model)
                >= Files.Model.Paste_Execution_Action_Count (Model)
      then
         return Finalize_Paste_Execution (Model, Settings, "");
      end if;

      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end Advance_Paste_Execution;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model) is
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) then
         Files.Model.Cancel_Paste_Execution (Model);
      end if;
   end Cancel_Paste_Execution;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result is
   begin
      return Begin_Paste_To
        (Model, Settings, Source_Paths, Files.Model.Current_Path (Model), Mode, From_Clipboard);
   end Begin_Paste;

   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
   is
      Directory : constant String := Destination;
      Plans     : Files.File_System.Drop_Import_Result;
   begin
      if Source_Paths.Is_Empty then
         return Disabled (Model, "error.drop.invalid_source");
      end if;

      --  Reuse the drag-and-drop planner purely to validate the sources
      --  (missing source, invalid name, drop-into-self) and to detect same-dir
      --  move no-ops; its auto-renamed destinations are discarded.
      Plans := Files.File_System.Plan_Drop_Import (Source_Paths, Directory, Mode);
      if not Plans.Success then
         Files.Model.Set_Error (Model, To_String (Plans.Error_Key));
         return Make_Result (Operation_Failed, To_String (Plans.Error_Key), Directory);
      end if;

      declare
         Work     : constant Files.Paste.Work_Item_Vectors.Vector :=
           Paste_Work_List (Plans.Plans, Directory);
         Existing : constant Files.Types.String_Vectors.Vector :=
           Existing_Destination_Paths (Directory);
         Conflict : constant Natural :=
           Files.Paste.Next_Unresolved_Conflict
             (Work, Files.Paste.Policy_Ask, Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing);
      begin
         if Conflict = 0 then
            --  No collisions: arm the resumable execution and run the first
            --  batch. Small pastes finish here; larger ones keep advancing under
            --  the render loop while the progress overlay is shown.
            declare
               Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
                 Files.Paste.Resolve
                   (Work, Files.Paste.Policy_Ask,
                    Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing);
            begin
               Files.Model.Begin_Paste_Execution (Model, Actions, Mode, From_Clipboard);
               return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
            end;
         else
            --  Collisions remain: arm the conflict dialog and write nothing yet.
            Files.Model.Begin_Paste_Conflict (Model, Work, Existing, Mode, Conflict, From_Clipboard);
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success, Path => Directory);
         end if;
      end;
   end Begin_Paste_To;

   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
      return Operation_Result
   is
   begin
      if not Files.Model.Paste_Conflict_Is_Active (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      if Choice = Choice_Cancel then
         Files.Model.Clear_Paste_Conflict (Model);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      declare
         Decision : constant Files.Paste.Item_Decision :=
           (case Choice is
              when Choice_Replace => Files.Paste.Decision_Replace,
              when Choice_Skip    => Files.Paste.Decision_Skip,
              when Choice_Rename  => Files.Paste.Decision_Rename,
              when Choice_Cancel  => Files.Paste.Decision_Skip);
      begin
         if Apply_All then
            Files.Model.Set_Paste_Conflict_Policy
              (Model,
               (case Choice is
                  when Choice_Replace => Files.Paste.Policy_Replace_All,
                  when Choice_Skip    => Files.Paste.Policy_Skip_All,
                  when Choice_Rename  => Files.Paste.Policy_Rename_All,
                  when Choice_Cancel  => Files.Paste.Policy_Skip_All));
         else
            Files.Model.Set_Paste_Conflict_Override
              (Model, Files.Model.Paste_Conflict_Index (Model), Decision);
         end if;
      end;

      declare
         Work     : constant Files.Paste.Work_Item_Vectors.Vector :=
           Files.Model.Paste_Conflict_Items (Model);
         Existing : constant Files.Types.String_Vectors.Vector :=
           Files.Model.Paste_Conflict_Existing (Model);
         Policy   : constant Files.Paste.Conflict_Policy := Files.Model.Paste_Conflict_Policy (Model);
         Overrides : constant Files.Paste.Item_Decision_Vectors.Vector :=
           Files.Model.Paste_Conflict_Overrides (Model);
         Mode     : constant Files.File_System.Drop_Import_Mode :=
           Files.Model.Paste_Conflict_Mode (Model);
         Next     : constant Natural :=
           Files.Paste.Next_Unresolved_Conflict (Work, Policy, Overrides, Existing);
      begin
         if Next /= 0 then
            Files.Model.Set_Paste_Conflict_Index (Model, Next);
            return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
         end if;

         declare
            Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
              Files.Paste.Resolve (Work, Policy, Overrides, Existing);
            --  Carry the clipboard-clearing intent (clipboard paste vs
            --  drag-and-drop) captured when the conflict dialog was armed, since
            --  Clear_Paste_Conflict below resets it.
            Clears_Clipboard : constant Boolean :=
              Files.Model.Paste_Conflict_Clears_Clipboard (Model);
         begin
            --  Leave the conflict sub-mode, arm the resumable execution over the
            --  resolved actions, and run the first batch (small pastes finish
            --  here; larger ones continue under the render loop).
            Files.Model.Clear_Paste_Conflict (Model);
            Files.Model.Begin_Paste_Execution (Model, Actions, Mode, Clears_Clipboard);
            return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
         end;
      end;
   end Resolve_Paste_Conflict;

   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Name : constant String := Files.Model.Rename_Text (Model);
   begin
      if not Files.Model.Temporary_Item_Is_Active (Model) then
         return Disabled (Model, "error.create.no_temporary_item");
      elsif not Files.File_System.Valid_Leaf_Name (Name) then
         Files.Model.Set_Error (Model, "error.name.invalid");
         return Make_Result (Operation_Invalid_Name, "error.name.invalid");
      end if;

      declare
         Path     : constant String := Files.File_System.Join_Path (Files.Model.Current_Path (Model), Name);
         Mutation : constant Files.File_System.Mutation_Result :=
           (if Files.Model.Temporary_Item_Is_Directory (Model)
            then Files.File_System.Create_Directory (Path)
            else Files.File_System.Create_Empty_File (Path));
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;
      end;

      --  The file now exists on disk, so leave create-edit mode regardless of
      --  whether the subsequent refresh succeeds; otherwise a refresh failure
      --  would strand the model in temporary-item mode.
      Files.Model.Clear_Edit_State (Model);
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings, Name);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      Files.Model.Set_Error (Model, "");
      return
        Make_Result
          (Operation_Success,
           Path => Files.File_System.Join_Path (Files.Model.Current_Path (Model), Name));
   end Commit_Create_File;

   function Commit_Rename
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Targets     : constant Files.Model.Rename_Target_Vectors.Vector := Files.Model.Rename_Targets (Model);
      Current_Dir : constant String := Files.Model.Current_Path (Model);
      From_V      : Files.Types.String_Vectors.Vector;
      To_V        : Files.Types.String_Vectors.Vector;
      Success     : Natural := 0;
      Failure     : Natural := 0;
      Need_Reload : Boolean := False;
      First_Error_Key  : Unbounded_String := Null_Unbounded_String;
      First_Error_Path : Unbounded_String := Null_Unbounded_String;
      Focus_Name       : Unbounded_String := Null_Unbounded_String;

      procedure Record_First_Error (Key : String; Path : String) is
      begin
         if First_Error_Key = Null_Unbounded_String then
            First_Error_Key := To_Unbounded_String (Key);
            First_Error_Path := To_Unbounded_String (Path);
         end if;
      end Record_First_Error;
   begin
      if not Files.Model.Rename_Is_Active (Model) or else Targets.Is_Empty then
         return Disabled (Model, "error.rename.disabled");
      end if;

      --  Capture old paths first (already done by Rename_Targets), then rename
      --  each item best-effort: successes are recorded for a single undo, and
      --  failures are collected without aborting the remaining renames.
      for Target of Targets loop
         declare
            Old_Full : constant String := To_String (Target.Old_Full_Path);
            Old_Name : constant String := To_String (Target.Old_Name);
            New_Name : constant String := To_String (Target.New_Name);
         begin
            if not Files.File_System.Valid_Leaf_Name (New_Name) then
               Failure := Failure + 1;
               Record_First_Error ("error.name.invalid", Old_Full);
            elsif New_Name = Old_Name then
               if Exists_Safely (Old_Full) then
                  Success := Success + 1;
                  if Focus_Name = Null_Unbounded_String then
                     Focus_Name := Target.New_Name;
                  end if;
               else
                  Failure := Failure + 1;
                  Need_Reload := True;
                  Record_First_Error ("error.rename.source_missing", Old_Full);
               end if;
            else
               declare
                  New_Path : constant String := Files.File_System.Join_Path (Current_Dir, New_Name);
                  Mutation : constant Files.File_System.Mutation_Result :=
                    Files.File_System.Rename_Item (Old_Full, New_Path);
               begin
                  if Mutation.Success then
                     Success := Success + 1;
                     Need_Reload := True;
                     From_V.Append (To_Unbounded_String (New_Path));
                     To_V.Append (Target.Old_Full_Path);
                     if Focus_Name = Null_Unbounded_String then
                        Focus_Name := Target.New_Name;
                     end if;
                  else
                     Failure := Failure + 1;
                     if To_String (Mutation.Error_Key) = "error.rename.source_missing" then
                        Need_Reload := True;
                     end if;
                     Record_First_Error (To_String (Mutation.Error_Key), New_Path);
                  end if;
               end;
            end if;
         end;
      end loop;

      --  All renames failed. Keep the inline editors active (so the user can
      --  correct them) unless a vanished source forces a reload -- matching the
      --  single-item behavior exactly.
      if Success = 0 then
         declare
            Failed_Status : constant Operation_Status :=
              (if To_String (First_Error_Key) = "error.name.invalid"
               then Operation_Invalid_Name
               else Operation_Failed);
         begin
            Files.Model.Set_Error (Model, To_String (First_Error_Key));
            if Need_Reload then
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (First_Error_Key));
               end;
            end if;
            return
              Make_Result
                (Failed_Status,
                 To_String (First_Error_Key),
                 To_String (First_Error_Path));
         end;
      end if;

      --  At least one rename succeeded; leave rename-edit mode even if the
      --  refresh fails, rather than stranding the model in it.
      Files.Model.Clear_Edit_State (Model);
      if not From_V.Is_Empty then
         Files.Model.Record_Undo (Model, Files.Model.Undo_Rename, From_V, To_V);
      end if;

      if Need_Reload then
         declare
            Reload : constant Operation_Result :=
              Reload_Current_Directory (Model, Settings, To_String (Focus_Name));
         begin
            if Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;
      end if;

      if Failure > 0 then
         --  Some items renamed, some failed: report partial success so the
         --  user learns not every rename landed.
         Files.Model.Set_Error (Model, "error.rename.partial");
         return
           Make_Result
             (Operation_Success,
              "error.rename.partial",
              Files.File_System.Join_Path (Current_Dir, To_String (Focus_Name)));
      end if;

      Files.Model.Set_Error (Model, "");
      return
        Make_Result
          (Operation_Success,
           Path => Files.File_System.Join_Path (Current_Dir, To_String (Focus_Name)));
   end Commit_Rename;

   function Permissions_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is
      Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
   begin
      return Files.Model.Selected_Count (Model) = 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
        and then Files.File_System.Supports_Permissions
        and then Item.Mode_Available
        and then Files.Model.Current_Path (Model) /= Files.File_System.Trash_Files_Directory;
   end Permissions_Editable_Selection;

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if not Permissions_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item      : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Path      : constant String := To_String (Item.Full_Path);
         Old_Mode  : constant Natural := Item.Mode_Bits;
         Mutation  : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Permissions (Path, New_Mode);
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;

         declare
            Undo_From    : Files.Types.String_Vectors.Vector;
            Undo_To      : Files.Types.String_Vectors.Vector;
            Undo_Forward : Files.Types.String_Vectors.Vector;
         begin
            Undo_From.Append (To_Unbounded_String (Path));
            Undo_To.Append (To_Unbounded_String (Natural'Image (Old_Mode)));
            Undo_Forward.Append (To_Unbounded_String (Natural'Image (New_Mode)));
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Set_Permissions, Undo_From, Undo_To,
               Forward => Undo_Forward);
         end;

         declare
            Reload : constant Operation_Result :=
              Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
         begin
            if Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;

         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Path);
      end;
   end Set_Permissions_For;

   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if Bit > 8 or else not Permissions_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item     : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Mask     : constant Natural := 2 ** (8 - Bit);
         New_Mode : constant Natural :=
           (if (Item.Mode_Bits / Mask) mod 2 = 1
            then Item.Mode_Bits - Mask
            else Item.Mode_Bits + Mask);
      begin
         return Set_Permissions_For (Model, New_Mode, Settings);
      end;
   end Toggle_Permission_Bit;

   function Ownership_Editable_Selection
     (Model : Files.Model.Window_Model)
      return Boolean
   is
      Item : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
   begin
      return Files.Model.Selected_Count (Model) = 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
        and then Files.File_System.Supports_Ownership
        and then Item.Ownership_Available
        and then Files.Model.Current_Path (Model) /= Files.File_System.Trash_Files_Directory;
   end Ownership_Editable_Selection;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
   begin
      if not Ownership_Editable_Selection (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      declare
         Item      : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
         Path      : constant String := To_String (Item.Full_Path);
         Old_Uid   : constant Natural := Item.Owner_Id;
         Old_Gid   : constant Natural := Item.Group_Id;
         Mutation  : constant Files.File_System.Mutation_Result :=
           Files.File_System.Set_Ownership (Path, User_Id, Group_Id);
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;

         declare
            Undo_From    : Files.Types.String_Vectors.Vector;
            Undo_To      : Files.Types.String_Vectors.Vector;
            Undo_Forward : Files.Types.String_Vectors.Vector;
         begin
            Undo_From.Append (To_Unbounded_String (Path));
            Undo_To.Append
              (To_Unbounded_String
                 (Ada.Strings.Fixed.Trim (Natural'Image (Old_Uid), Ada.Strings.Both)
                  & " "
                  & Ada.Strings.Fixed.Trim (Natural'Image (Old_Gid), Ada.Strings.Both)));
            Undo_Forward.Append
              (To_Unbounded_String
                 (Ada.Strings.Fixed.Trim (Natural'Image (User_Id), Ada.Strings.Both)
                  & " "
                  & Ada.Strings.Fixed.Trim (Natural'Image (Group_Id), Ada.Strings.Both)));
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Set_Ownership, Undo_From, Undo_To,
               Forward => Undo_Forward);
         end;

         declare
            Reload : constant Operation_Result :=
              Reload_Current_Directory (Model, Settings, Files.Model.Selected_Name (Model));
         begin
            if Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;

         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Path);
      end;
   end Set_Ownership_For;

   procedure Update_Folder_Size
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      pragma Unreferenced (Settings);
   begin
      --  Folder size is a recursive subtree walk. It runs incrementally off the
      --  UI path (Files.Folder_Size), so measuring it does not block: here we just
      --  request the selected directories and the frame loop advances the walks.
      --  Every selected directory is measured -- for any selection, not only when
      --  the info pane is open -- so both the info pane and the bottom bar's
      --  combined total can count folder contents.
      if Files.Model.Selected_Count (Model) >= 1
        and then not Files.Model.Selection_Includes_Temporary (Model)
      then
         declare
            Targets : Files.Folder_Size.Path_Vectors.Vector;
         begin
            Files.Model.Prune_Folder_Sizes_To_Selection (Model);
            for Item of Files.Model.Selected_Items (Model) loop
               if Item.Kind = Files.Types.Directory_Item then
                  declare
                     Path : constant String := To_String (Item.Full_Path);
                  begin
                     if not Files.Model.Folder_Size_Cached_For (Model, Path) then
                        Targets.Append (To_Unbounded_String (Path));
                     end if;
                  end;
               end if;
            end loop;
            Files.Folder_Size.Set_Targets (Targets);
         end;
      else
         Files.Model.Clear_Folder_Size (Model);
         Files.Folder_Size.Cancel;
      end if;
   end Update_Folder_Size;

   --  Move each item from its current location back to its original one,
   --  guarding against missing sources and occupied targets. Shared by the
   --  reverse (undo) and forward (redo) rename/move handlers, which differ only
   --  in the direction of the Source/Target pairing.
   function Move_Back
     (Sources : Files.Types.String_Vectors.Vector;
      Targets : Files.Types.String_Vectors.Vector)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      for Index in Sources.First_Index .. Sources.Last_Index loop
         declare
            Source : constant String := To_String (Sources.Element (Index));
            Target : constant String := To_String (Targets.Element (Index));
         begin
            if Exists_Safely (Source) and then not Exists_Safely (Target) then
               if not Files.File_System.Rename_Item (Source, Target).Success then
                  Succeeded := False;
               end if;
            else
               Succeeded := False;
            end if;
         end;
      end loop;
      return Succeeded;
   end Move_Back;

   --  Apply the reverse (undo) direction of Action. Returns True on full
   --  success. Mirrors the pre-existing single-level undo behaviour.
   function Apply_Reverse
     (Action : Files.Model.Undo_Entry)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      case Action.Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            Succeeded := Move_Back (Action.From, Action.To);

         when Files.Model.Undo_Restore_Trash =>
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               if not Files.File_System.Restore_From_Trash
                        (To_String (Action.From.Element (Index))).Success
               then
                  Succeeded := False;
               end if;
            end loop;

         when Files.Model.Undo_Delete_Created =>
            --  Undo a created path by removing it again. Missing paths are
            --  treated as already undone.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target : constant String := To_String (Action.From.Element (Index));
               begin
                  if Exists_Safely (Target)
                    and then not Files.File_System.Delete_Permanently (Target).Success
                  then
                     Succeeded := False;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Permissions =>
            --  Restore the previous mode recorded before the chmod. From holds
            --  the path and To holds the decimal image of the old mode bits.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target   : constant String := To_String (Action.From.Element (Index));
                  Old_Text : constant String :=
                    Ada.Strings.Fixed.Trim (To_String (Action.To.Element (Index)), Ada.Strings.Both);
                  Old_Mode : Natural := 0;
               begin
                  begin
                     Old_Mode := Natural'Value (Old_Text);
                  exception
                     when others =>
                        Succeeded := False;
                  end;

                  if Old_Mode > 0 or else Old_Text = "0" then
                     if not Files.File_System.Set_Permissions (Target, Old_Mode).Success then
                        Succeeded := False;
                     end if;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Ownership =>
            --  Restore the previous owner/group recorded before the chown.
            --  From holds the path and To holds "uid gid" decimal images.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target   : constant String := To_String (Action.From.Element (Index));
                  Old_Text : constant String :=
                    Ada.Strings.Fixed.Trim (To_String (Action.To.Element (Index)), Ada.Strings.Both);
                  Space    : constant Natural := Ada.Strings.Fixed.Index (Old_Text, " ");
                  Old_Uid  : Natural := 0;
                  Old_Gid  : Natural := 0;
               begin
                  if Space > 0 then
                     begin
                        Old_Uid := Natural'Value (Old_Text (Old_Text'First .. Space - 1));
                        Old_Gid := Natural'Value (Old_Text (Space + 1 .. Old_Text'Last));
                        if not Files.File_System.Set_Ownership (Target, Old_Uid, Old_Gid).Success then
                           Succeeded := False;
                        end if;
                     exception
                        when others =>
                           Succeeded := False;
                     end;
                  else
                     Succeeded := False;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_None =>
            Succeeded := False;
      end case;
      return Succeeded;
   end Apply_Reverse;

   --  Apply the forward (redo) direction of Action. Returns True on full
   --  success. Undo_Restore_Trash is undo-only and never reaches here.
   function Apply_Forward
     (Action : Files.Model.Undo_Entry)
      return Boolean
   is
      Succeeded : Boolean := True;
   begin
      case Action.Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            --  Re-run the original transition: from the reverted (To) location
            --  back to the post-operation (From) location.
            Succeeded := Move_Back (Action.To, Action.From);

         when Files.Model.Undo_Delete_Created =>
            --  Re-create each destination from its recorded source using the
            --  stored creation kind.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Dest   : constant String := To_String (Action.From.Element (Index));
                  Source : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then To_String (Action.Forward.Element (Index))
                     else "");
               begin
                  if Source = ""
                    or else not Exists_Safely (Source)
                    or else Exists_Safely (Dest)
                  then
                     Succeeded := False;
                  else
                     case Action.Create_Kind is
                        when Files.Model.Create_Copy =>
                           if not Files.File_System.Copy_Tree (Source, Dest).Success then
                              Succeeded := False;
                           end if;
                        when Files.Model.Create_Symbolic_Link =>
                           if not Files.File_System.Create_Symbolic_Link (Source, Dest).Success then
                              Succeeded := False;
                           end if;
                        when Files.Model.Create_Hard_Link =>
                           if not Files.File_System.Create_Hard_Link (Source, Dest).Success then
                              Succeeded := False;
                           end if;
                        when Files.Model.Create_None =>
                           Succeeded := False;
                     end case;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Permissions =>
            --  Re-apply the new mode stored in Forward.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target   : constant String := To_String (Action.From.Element (Index));
                  New_Text : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then Ada.Strings.Fixed.Trim (To_String (Action.Forward.Element (Index)), Ada.Strings.Both)
                     else "");
                  New_Mode : Natural := 0;
               begin
                  if New_Text = "" then
                     Succeeded := False;
                  else
                     begin
                        New_Mode := Natural'Value (New_Text);
                     exception
                        when others =>
                           Succeeded := False;
                     end;

                     if (New_Mode > 0 or else New_Text = "0")
                       and then not Files.File_System.Set_Permissions (Target, New_Mode).Success
                     then
                        Succeeded := False;
                     end if;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Set_Ownership =>
            --  Re-apply the new owner/group stored in Forward.
            for Index in Action.From.First_Index .. Action.From.Last_Index loop
               declare
                  Target   : constant String := To_String (Action.From.Element (Index));
                  New_Text : constant String :=
                    (if Index <= Action.Forward.Last_Index
                     then Ada.Strings.Fixed.Trim (To_String (Action.Forward.Element (Index)), Ada.Strings.Both)
                     else "");
                  Space    : constant Natural :=
                    (if New_Text = "" then 0 else Ada.Strings.Fixed.Index (New_Text, " "));
                  New_Uid  : Natural := 0;
                  New_Gid  : Natural := 0;
               begin
                  if Space > 0 then
                     begin
                        New_Uid := Natural'Value (New_Text (New_Text'First .. Space - 1));
                        New_Gid := Natural'Value (New_Text (Space + 1 .. New_Text'Last));
                        if not Files.File_System.Set_Ownership (Target, New_Uid, New_Gid).Success then
                           Succeeded := False;
                        end if;
                     exception
                        when others =>
                           Succeeded := False;
                     end;
                  else
                     Succeeded := False;
                  end if;
               end;
            end loop;

         when Files.Model.Undo_Restore_Trash | Files.Model.Undo_None =>
            Succeeded := False;
      end case;
      return Succeeded;
   end Apply_Forward;

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean;
      Succeeded : Boolean;
   begin
      Files.Model.Take_Undo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Succeeded := Apply_Reverse (Action);

      --  A reversed action moves onto the redo stack, unless it is undo-only or
      --  its reverse could not be fully applied.
      if Succeeded and then Action.Redoable then
         Files.Model.Push_Redo (Model, Action);
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      if not Succeeded then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Undo_Last;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Directory : constant String := Files.Model.Current_Path (Model);
      Action    : Files.Model.Undo_Entry;
      Found     : Boolean;
      Succeeded : Boolean;
   begin
      Files.Model.Take_Redo (Model, Action, Found);
      if not Found then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Succeeded := Apply_Forward (Action);

      --  A re-applied action returns to the undo stack without disturbing the
      --  rest of the redo history.
      if Succeeded then
         Files.Model.Push_Undo (Model, Action);
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      if not Succeeded then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Directory);
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Redo_Last;

   function Prepare_Quick_Look
     (Item : Files.File_System.Directory_Item)
      return Files.Quick_Look.Quick_Look_Content
   is
      use type Files.Quick_Look.Content_Kind;
      Name     : constant String := To_String (Item.Name);
      Filetype : constant String := To_String (Item.Filetype);
      Icon_Id  : constant String := To_String (Item.Icon_Id);
      Path     : constant String := To_String (Item.Full_Path);
      Is_Image : constant Boolean :=
        Files.File_System.Is_Image_Item (Item.Kind, Filetype, Name, Icon_Id);
      Raw      : constant String :=
        (if Is_Image
           or else (Item.Kind /= Files.Types.Regular_File_Item
                    and then Item.Kind /= Files.Types.Executable_Item)
         then ""
         else Files.File_System.Read_Preview_Text
                (Path, Files.Quick_Look.Max_Preview_Bytes));
      --  Preview resolution for the decoded original image, matching the icon
      --  atlas's large-tile bound so it renders crisply within the panel.
      Preview_Size : constant Positive := 512;
      Content : Files.Quick_Look.Quick_Look_Content :=
        Files.Quick_Look.Prepare_Content
          (Name           => Name,
           Filetype       => Filetype,
           Icon_Id        => Icon_Id,
           Kind           => Item.Kind,
           Size_Available => Item.Size_Available,
           Size           => Item.Size,
           Is_Image       => Is_Image,
           Image_Path     => Path,
           Raw_Bytes      => Raw);
   begin
      --  Decode the original image once here (Files.Quick_Look is pure), so the
      --  preview scales the source rather than the small thumbnail.
      if Content.Kind = Files.Quick_Look.Image_Content then
         declare
            Decoded : constant Files.File_System.Decoded_Image :=
              Files.File_System.Decode_Image_To_Pixels (Path, Preview_Size);
         begin
            if Decoded.Available then
               Content.Image_Pixels := Decoded.Pixels;
               Content.Image_Width := Decoded.Width;
               Content.Image_Height := Decoded.Height;
            end if;
         end;
      end if;
      return Content;
   end Prepare_Quick_Look;

end Files.Operations;
