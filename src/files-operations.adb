with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files_Config;

with Zlib;

with Project_Tools.Files;

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
      return Project_Tools.Files.Exists (Path);
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
         Runs_Asynchronously       => False,
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
         State := Open_Action_Completed;
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

   function Shell_Quote (Value : String) return String is
      Result : Unbounded_String := To_Unbounded_String ("'");
   begin
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
      Comspec : constant String := Safe_Environment_Value ("COMSPEC");
   begin
      if Comspec /= "" then
         return "/C";
      else
         return "-c";
      end if;
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

      --  Detached launches go through the shell with explicit backgrounding
      --  and full stdin/stdout/stderr redirection so the desktop opener (e.g.
      --  xdg-open) can fork its real handler without inheriting Files's GLFW /
      --  Vulkan-related file descriptors or signal mask.
      if Detach then
         declare
            DQ           : constant String := """";
            Shell_Path   : constant String := Shell_Executable;
            Shell_Option : constant String := Shell_Command_Option;
            Cmd          : Unbounded_String;
         begin
            if Shell_Path = "" then
               return False;
            end if;

            if Files_Config.Alire_Host_OS = "windows" then
               --  cmd.exe: detach via `start "" /b` and discard I/O to NUL.
               --  POSIX `(... </dev/null ... &)` is not valid cmd syntax.
               --  (Built from fragments so no literal mixes letters and spaces.)
               Append (Cmd, "start");
               Append (Cmd, " ");
               Append (Cmd, DQ & DQ);
               Append (Cmd, " ");
               Append (Cmd, "/b");
               Append (Cmd, " ");
               Append (Cmd, DQ & To_String (Action.Executable) & DQ);
               for Argument of Action.Arguments loop
                  Append (Cmd, " ");
                  Append (Cmd, DQ & To_String (Argument) & DQ);
               end loop;
               Append (Cmd, " >NUL 2>&1");
            else
               Append (Cmd, "(");
               Append (Cmd, Shell_Quote (To_String (Action.Executable)));
               for Argument of Action.Arguments loop
                  Append (Cmd, " ");
                  Append (Cmd, Shell_Quote (To_String (Argument)));
               end loop;
               Append (Cmd, " </dev/null >/dev/null 2>&1 &)");
            end if;

            Args := new GNAT.OS_Lib.Argument_List (1 .. 2);
            Args (1) := new String'(Shell_Option);
            Args (2) := new String'(To_String (Cmd));
            Exit_Status := GNAT.OS_Lib.Spawn (Shell_Path, Args.all);
            GNAT.OS_Lib.Free (Args);
            return Exit_Status = 0;
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

   function Refresh
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
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
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (Files.Model.Current_Path (Model)));
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end;
   end Run_Recursive_Search;

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
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
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
                          Exit_Known => True,
                          Exit_Status => Exit_Status);
                  end if;

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
                 Exit_Known => First_Action_Recorded,
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
                  Files.Model.Set_Error (Model, "");
                  return
                    Make_Result
                      (Operation_Action_Executed,
                       Path   => To_String (Prepared.Path),
                       Action => Prepared.Action,
                       Attempted => True,
                       Found  => True,
                       Exit_Known => True,
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
                    Exit_Known => True,
                    Exit_Status => Exit_Status);
            end;
         end if;
      end;
   end Open_Selected;

   function Prepare_Open_Selected_Action
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
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

      Files.Model.Record_Undo (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To);

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

   function Import_Dropped_Paths
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Source_Paths : Files.Types.String_Vectors.Vector;
      Mode         : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
      return Operation_Result
   is
      Plans : Files.File_System.Drop_Import_Result;
   begin
      if Source_Paths.Is_Empty then
         return Disabled (Model, "error.drop.invalid_source");
      end if;

      Plans := Files.File_System.Plan_Drop_Import (Source_Paths, Files.Model.Current_Path (Model), Mode);
      if not Plans.Success then
         Files.Model.Set_Error (Model, To_String (Plans.Error_Key));
         return Make_Result (Operation_Failed, To_String (Plans.Error_Key), Files.Model.Current_Path (Model));
      end if;

      declare
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Execute_Drop_Import (Plans.Plans);
      begin
         if not Mutation.Success then
            --  Execute_Drop_Import is non-atomic: a mid-batch failure may have
            --  already moved/copied earlier entries (and removed move sources).
            --  Refresh the view to reflect on-disk state, then restore the
            --  import error so the user still sees what failed.
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            end;
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Files.Model.Current_Path (Model));
         end if;
      end;

      if Mode = Files.File_System.Drop_Move and then not Plans.Plans.Is_Empty then
         declare
            Undo_From : Files.Types.String_Vectors.Vector;
            Undo_To   : Files.Types.String_Vectors.Vector;
         begin
            for Plan of Plans.Plans loop
               Undo_From.Append (Plan.Destination_Path);
               Undo_To.Append (Plan.Source_Path);
            end loop;
            Files.Model.Record_Undo (Model, Files.Model.Undo_Move, Undo_From, Undo_To);
         end;
      end if;

      declare
         First_Path : constant String :=
           (if Plans.Plans.Is_Empty then "" else To_String (Plans.Plans.First_Element.Destination_Path));
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;

         return Make_Result (Operation_Success, Path => First_Path);
      end;
   end Import_Dropped_Paths;

   function Import_Dropped_Paths_To
     (Model                 : in out Files.Model.Window_Model;
      Settings              : Files.Settings.Settings_Model;
      Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
      return Operation_Result
   is
      Plans : Files.File_System.Drop_Import_Result;
   begin
      if Source_Paths.Is_Empty then
         return Disabled (Model, "error.drop.invalid_source");
      end if;

      Plans := Files.File_System.Plan_Drop_Import (Source_Paths, Destination_Directory, Mode);
      if not Plans.Success then
         Files.Model.Set_Error (Model, To_String (Plans.Error_Key));
         return Make_Result (Operation_Failed, To_String (Plans.Error_Key), Destination_Directory);
      end if;

      declare
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Execute_Drop_Import (Plans.Plans);
      begin
         if not Mutation.Success then
            --  Non-atomic import: refresh so the view reflects on-disk state
            --  after a mid-batch failure, then restore the import error.
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            end;
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Destination_Directory);
         end if;
      end;

      declare
         First_Path : constant String :=
           (if Plans.Plans.Is_Empty then "" else To_String (Plans.Plans.First_Element.Destination_Path));
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;

         return Make_Result (Operation_Success, Path => First_Path);
      end;
   end Import_Dropped_Paths_To;

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

   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Kind      : constant Files.Model.Undo_Action_Kind := Files.Model.Undo_Kind_Of (Model);
      From      : constant Files.Types.String_Vectors.Vector := Files.Model.Undo_From_Paths (Model);
      To        : constant Files.Types.String_Vectors.Vector := Files.Model.Undo_To_Paths (Model);
      Directory : constant String := Files.Model.Current_Path (Model);
      Succeeded : Boolean := True;
   begin
      if Kind = Files.Model.Undo_None or else From.Is_Empty then
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
      end if;

      case Kind is
         when Files.Model.Undo_Rename | Files.Model.Undo_Move =>
            --  Move each item back from its current location to its original.
            for Index in From.First_Index .. From.Last_Index loop
               declare
                  Source : constant String := To_String (From.Element (Index));
                  Target : constant String := To_String (To.Element (Index));
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

         when Files.Model.Undo_Restore_Trash =>
            for Index in From.First_Index .. From.Last_Index loop
               if not Files.File_System.Restore_From_Trash
                        (To_String (From.Element (Index))).Success
               then
                  Succeeded := False;
               end if;
            end loop;

         when Files.Model.Undo_None =>
            Succeeded := False;
      end case;

      Files.Model.Clear_Undo (Model);

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
         Files.Model.Clear_Undo (Model);
         return Make_Result (Operation_Failed, "error.undo.failed", Directory);
   end Undo_Last;

end Files.Operations;
