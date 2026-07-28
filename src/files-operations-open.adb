with Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with Files.File_System;
with Files.Types;

with Hostkit;
with Hostkit.Process;
with Hostkit.Shell;

with Files.Operations.Support;

package body Files.Operations.Open is
   use Ada.Strings.Unbounded;
   use type Files.Types.Item_Kind;
   use type GNAT.OS_Lib.Argument_List_Access;
   use type GNAT.OS_Lib.String_Access;
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

end Files.Operations.Open;
