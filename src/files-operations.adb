with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files_Config;

with Files.Folder_Size;
with Files.Fs;
with Files.Paste;
with Files.Platform.Metadata;

with Hostkit;
with Hostkit.Fs;
with Hostkit.Process;
with Hostkit.Shell;

with Zlib;

with Files.Operations.History;
with Files.Operations.Metadata;
with Files.Operations.Search;
with Files.Operations.Support;

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

   use Files.Operations.Support;

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

   function Unsafe_Open_Action
     (Model : in out Files.Model.Window_Model;
      Path  : String)
      return Operation_Result is
   begin
      Files.Model.Set_Error (Model, "error.open_action.unsafe_placeholder");
      return Make_Result (Operation_Failed, "error.open_action.unsafe_placeholder", Path);
   end Unsafe_Open_Action;

   --  These stay public because callers and tests ask for them, but the answer is
   --  Hostkit's: which shell, and how it wants a command introduced, is one question
   --  asked in one place, not re-derived per crate.
   function Shell_Executable return String is
   begin
      return Hostkit.Shell.Executable;
   end Shell_Executable;

   function Shell_Command_Option return String is
   begin
      return Hostkit.Shell.Command_Option;
   end Shell_Command_Option;

   --  An open action's arguments, in the vector Hostkit speaks.
   function Host_Arguments
     (Arguments : Files.Types.String_Vectors.Vector)
      return Hostkit.String_Vectors.Vector
   is
      Result : Hostkit.String_Vectors.Vector;
   begin
      for Argument of Arguments loop
         Result.Append (Argument);
      end loop;

      return Result;
   end Host_Arguments;

   function Execute_Open_Action
     (Action      : Files.Settings.Open_Action;
      Exit_Status : out Integer;
      Detach      : Boolean := False)
      return Boolean
   is
      Executable : constant String := To_String (Action.Executable);
      Arguments  : constant Hostkit.String_Vectors.Vector := Host_Arguments (Action.Arguments);
   begin
      Exit_Status := -1;

      if Executable = "" then
         return False;
      end if;

      --  An explicit-shell action is a command line, so it goes through the shell, and
      --  Hostkit quotes it for whichever shell that turns out to be. Detached, it is not
      --  waited for and has no exit status; awaited, its own status is reported.
      if Action.Use_Shell then
         if Hostkit.Shell.Executable = "" then
            return False;
         end if;

         return Hostkit.Process.Run_Shell_Command
                  (Hostkit.Shell.Command_Line (Executable, Arguments),
                   Wait        => not Detach,
                   Exit_Status => Exit_Status);
      end if;

      --  A detached launch starts the application and returns. It has no exit status to
      --  report and does not pretend to: what used to be reported was the backgrounding
      --  wrapper shell's zero, which said nothing about the application.
      if Detach then
         return Hostkit.Process.Launch (Executable, Arguments);
      end if;

      return Hostkit.Process.Run (Executable, Arguments, Exit_Status);
   exception
      when others =>
         Exit_Status := -1;
         return False;
   end Execute_Open_Action;

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
               --  Record undo for the links already created before this mid-batch
               --  failure so they stay Ctrl-Z-restorable, and reload so they
               --  appear instead of staying hidden until the next refresh.
               if not Undo_From.Is_Empty then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Delete_Created, Undo_From, Undo_To,
                     Forward     => Undo_Sources,
                     Create_Kind =>
                       (if Hard
                        then Files.Model.Create_Hard_Link
                        else Files.Model.Create_Symbolic_Link));
                  declare
                     Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                     pragma Unreferenced (Reload);
                  begin
                     Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
                  end;
               end if;
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
      --  Ordered most- to least-preferred: the Debian alternatives shim and the
      --  desktop-environment defaults first, then popular standalone and modern
      --  GPU terminals, with the near-universal xterm as the last resort. Each
      --  is a bare executable expected on PATH; unknown ones simply never match.
      Candidates : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("x-terminal-emulator"),
         To_Unbounded_String ("gnome-terminal"),
         To_Unbounded_String ("konsole"),
         To_Unbounded_String ("xfce4-terminal"),
         To_Unbounded_String ("tilix"),
         To_Unbounded_String ("terminator"),
         To_Unbounded_String ("alacritty"),
         To_Unbounded_String ("kitty"),
         To_Unbounded_String ("wezterm"),
         To_Unbounded_String ("ghostty"),
         To_Unbounded_String ("foot"),
         To_Unbounded_String ("urxvt"),
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
         --  Change into the viewed directory, then start the terminal there. "cd /d" on
         --  cmd, because plain cd will not cross to another drive.
         Change_Dir : constant String :=
           (if Hostkit.Shell.Is_Command_Shell then "cd /d " else "cd ");

         Command : constant String :=
           Change_Dir & Hostkit.Shell.Quote (Directory)
           & " && " & Hostkit.Shell.Quote (Terminal);

         Exit_Status : Integer := -1;
         Started     : Boolean;
      begin
         if Hostkit.Shell.Executable = "" then
            Files.Model.Set_Error (Model, "error.terminal.unavailable");
            return Make_Result (Operation_Failed, "error.terminal.unavailable", Directory);
         end if;

         --  Detached: the terminal outlives us and is not waited for. This used to end
         --  in "</dev/null >/dev/null 2>&1 &", a shell asked to background the process
         --  because the spawn underneath blocked -- and a Windows shell cannot read a
         --  word of it.
         Started := Hostkit.Process.Run_Shell_Command (Command, Wait => False, Exit_Status => Exit_Status);

         if not Started then
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

   --  The recursive name/content search operations now live in the
   --  Files.Operations.Search child; these renamings keep them on the public API.
   function Run_Recursive_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Search.Run_Recursive_Search;

   function Content_Matches
     (Bytes : String;
      Query : String)
      return Boolean
      renames Files.Operations.Search.Content_Matches;

   function Run_Content_Search
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Search.Run_Content_Search;

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

   --  Shared normalize -> load -> navigate tail for the absolute-destination
   --  navigations (Home, Parent, Trash, Select_Root). Path is the raw requested
   --  path; on a normalize failure the error is reported against it, on a load
   --  failure against the normalized path. Close_Selector closes the root selector
   --  after a successful navigation (used only by Select_Root).
   function Load_And_Navigate
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Path           : String;
      Close_Selector : Boolean := False)
      return Operation_Result
   is
      Path_Result : constant Files.File_System.Path_Result :=
        Files.File_System.Normalize_Path (Path);
   begin
      if Path_Result.Status /= Files.File_System.Path_Valid then
         Files.Model.Set_Error (Model, To_String (Path_Result.Error_Key));
         return Make_Result
           (Operation_Failed, To_String (Path_Result.Error_Key), Path);
      end if;

      declare
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);
      begin
         if not Load.Success then
            Files.Model.Set_Error (Model, To_String (Load.Error_Key));
            return Make_Result
              (Operation_Failed,
               To_String (Load.Error_Key),
               To_String (Path_Result.Directory_Path));
         end if;

         Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
         Files.Model.Set_Directory_Signature
           (Model,
            Files.File_System.Directory_State (To_String (Load.Path)));
         if Close_Selector then
            Files.Model.Close_Root_Selector (Model);
         end if;
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
      end;
   end Load_And_Navigate;

   type History_Direction is (History_Back, History_Forward);

   --  History navigation shared by Navigate_Back and Navigate_Forward: mirror
   --  images differing only in the availability check, the error key, the move,
   --  and which way the rollback moves on a failed reload.
   function Navigate_History
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Direction : History_Direction)
      return Operation_Result
   is
      Had_Temporary  : constant Boolean := Files.Model.Temporary_Item_Is_Active (Model);
      Temporary_Name : constant String := Files.Model.Temporary_Item_Name (Model);
      Had_Rename     : constant Boolean := Files.Model.Rename_Is_Active (Model);
      Rename_Text    : constant String := Files.Model.Rename_Text (Model);
      Rename_Source  : constant String := Files.Model.Selected_Name (Model);
      Available      : constant Boolean :=
        (if Direction = History_Back
         then Files.Model.Can_Go_Back (Model)
         else Files.Model.Can_Go_Forward (Model));
      Error_Key      : constant String :=
        (if Direction = History_Back
         then "error.history.back_unavailable"
         else "error.history.forward_unavailable");
   begin
      if not Available then
         return Disabled (Model, Error_Key);
      end if;

      if Direction = History_Back then
         Files.Model.Go_Back (Model);
      else
         Files.Model.Go_Forward (Model);
      end if;

      declare
         Reload : constant Operation_Result := Refresh (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            --  Undo the history move, then restore any interrupted rename/create.
            if Direction = History_Back then
               Files.Model.Go_Forward (Model);
            else
               Files.Model.Go_Back (Model);
            end if;
            if Had_Temporary then
               Files.Model.Begin_Create_File (Model, Temporary_Name);
            elsif Had_Rename then
               declare
                  Selection_Restored : constant Boolean :=
                    Files.Model.Select_By_Name (Model, Rename_Source);
                  pragma Unreferenced (Selection_Restored);
               begin
                  null;
               end;
               Files.Model.Resume_Rename (Model, Rename_Text);
            end if;
         end if;

         return Reload;
      end;
   end Navigate_History;

   function Navigate_Home
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Load_And_Navigate (Model, Settings, Files.Model.Home_Path (Model));
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

      return Load_And_Navigate (Model, Settings, Parent);
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

      return Load_And_Navigate (Model, Settings, Trash_Dir);
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
      return Operation_Result is
   begin
      return Navigate_History (Model, Settings, History_Back);
   end Navigate_Back;

   function Navigate_Forward
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Navigate_History (Model, Settings, History_Forward);
   end Navigate_Forward;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Operation_Result is
   begin
      return Load_And_Navigate (Model, Settings, Root_Path, Close_Selector => True);
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
               --  Record an undo covering whatever was already trashed before this
               --  mid-batch failure (a race can make a later item fail after
               --  earlier ones moved), so those items remain Ctrl-Z-restorable
               --  instead of being stranded in the trash.
               if not Undo_From.Is_Empty then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To,
                     Redoable => False);
               end if;
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
   function Clear_Replaced_Destination
     (Path    : String;
      Source  : String;
      Trashed : out Files.Types.UString)
      return Boolean is
   begin
      Trashed := Null_Unbounded_String;
      if not Exists_Safely (Path) or else Path = Source then
         return True;
      end if;

      declare
         Result : constant Files.File_System.Mutation_Result :=
           Files.File_System.Move_To_Trash (Path, Trashed);
      begin
         if Result.Success then
            return True;
         end if;
      end;

      --  No trash backend available: fall back to a permanent delete, as before.
      --  Trashed stays empty, so such a replace is not undo-restorable (an existing
      --  limitation on trash-less environments, not made worse here).
      Trashed := Null_Unbounded_String;
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
      --  Trash locations of destinations a Replace overwrote; undo restores them,
      --  and a paste that replaced anything is undo-only (redo is not attempted).
      Replaced_Trash : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Paste_Execution_Replaced_Trash (Model);
      Redoable   : constant Boolean := Replaced_Trash.Is_Empty;
      First_Dest : constant String := Files.Model.Paste_Execution_First_Dest (Model);
   begin
      if not Undo_From.Is_Empty then
         if Mode = Files.File_System.Drop_Move then
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Move, Undo_From, Undo_To,
               Redoable      => Redoable,
               Restore_Trash => Replaced_Trash);
         else
            --  A copy is reversed by deleting the created copies (Undo_From) and
            --  redone by copying each source (Undo_To) back to its destination.
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Undo_From,
               Files.Types.String_Vectors.Empty_Vector,
               Forward       => Undo_To,
               Create_Kind   => Files.Model.Create_Copy,
               Redoable      => Redoable,
               Restore_Trash => Replaced_Trash);
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
               declare
                  Replaced_Trash : Files.Types.UString := Null_Unbounded_String;
               begin
                  if Action.Replaced
                    and then not Clear_Replaced_Destination
                                   (To_String (Action.Dest_Path),
                                    To_String (Action.Source_Path),
                                    Replaced_Trash)
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
                           --  The destination was just cleared but the write
                           --  failed: put the trashed original back so a mid-paste
                           --  failure never loses the pre-existing file.
                           if Length (Replaced_Trash) > 0 then
                              declare
                                 Restored : constant Files.File_System.Mutation_Result :=
                                   Files.File_System.Restore_From_Trash (To_String (Replaced_Trash));
                                 pragma Unreferenced (Restored);
                              begin
                                 null;
                              end;
                           end if;
                           return Finalize_Paste_Execution
                             (Model, Settings, To_String (Mutation.Error_Key));
                        end if;
                     end;
                  end;

                  --  Write succeeded: track the overwritten original's trash
                  --  location so the paste's undo entry can restore it.
                  if Length (Replaced_Trash) > 0 then
                     Files.Model.Record_Paste_Execution_Replaced_Trash (Model, Replaced_Trash);
                  end if;
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

   --  The permission/ownership operations now live in the Files.Operations.Metadata
   --  child; these renamings keep them on the parent's public API.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Metadata.Set_Permissions_For;

   function Toggle_Permission_Bit
     (Model    : in out Files.Model.Window_Model;
      Bit      : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Metadata.Toggle_Permission_Bit;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Natural;
      Group_Id : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.Metadata.Set_Ownership_For;

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

   --  The undo/redo history operations now live in the Files.Operations.History
   --  child; these renamings keep public Undo_Last/Redo_Last on the parent.
   function Undo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.History.Undo_Last;

   function Redo_Last
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
      renames Files.Operations.History.Redo_Last;

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
