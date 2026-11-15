with Files.Window_Polls;
with Files.Foreground_Jobs;
with Files.Items;
with Files.Commands.Status;
with Ada.Strings.Unbounded;

with Guikit.Settings_Panel;

with Files.Desktop_Applications;
with Files.Breadcrumbs;
with Files.Command_Palette;
with Files.Folder_Tree;
with Files.Settings_Form;
with Guikit.Utf8.Editing;
with Files.Model.Command_Palette;
with Files.Model.Root_Selector;
with Files.Model.Settings_Pane;
with Files.Model.Tree_Panel;
with Files.Model.Pasting;
with Files.Model.Rename;
with Files.Model.Selection;
with Files.Settings.Open_Actions;
with Files.Settings.Path_References;

package body Files.Controller is
   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Root_Kind;
   use type Files.Model.Palette_Mode;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Operation_Results.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;

   --  Overlays without a text-entry surface own native character input.  This
   --  predicate lives at the controller boundary because GLFW character and
   --  file-drop callbacks bypass the ordinary key/click translators.
   function Non_Text_Overlay_Owns_Input
     (Model : Files.Model.Window_Model) return Boolean renames Files.Model.Non_Text_Overlay_Owns_Input;

   --  Settings and the command palette accept native character input only while
   --  their own text surface holds focus.  This also contains characters after
   --  focus has been cancelled without closing the overlay.
   function Text_Overlay_Rejects_Character_Input
     (Model : Files.Model.Window_Model) return Boolean is
     (if Files.Model.Command_Palette.Is_Open (Model) then
         Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      elsif Files.Model.Settings_Pane.Is_Open (Model) then
         Files.Model.Focus (Model) /= Files.Types.Focus_Settings_Input
      else
         False);

   function Empty_Operation return Files.Operation_Results.Operation_Result is
   begin
      return
        (Status    => Files.Operation_Results.Operation_Disabled,
         Error_Key => Null_Unbounded_String,
         Path      => Null_Unbounded_String,
         Action    => Files.Settings.Open_Actions.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
         others    => <>);
   end Empty_Operation;

   procedure Follow_Favorites
     (Model    : in out Files.Model.Window_Model;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model)
   is
   begin
      --  Seeding reads the volumes: only for a changed favorites list.
      if Files.Model.Tree_Panel.Is_Seeded (Model)
        and then not Files.Settings.Path_References.Same_Favorites
          (Settings, Files.Settings.Path_References.Favorite_Paths (Before))
      then
         Files.Operations.Seed_Tree (Model, Settings);
      end if;
   end Follow_Favorites;

   --  The one place settings are written. An empty path turns persistence
   --  off (smoke runs, tests): the settings apply in memory and count as saved.
   --  A session whose settings file could not be loaded refuses to write it:
   --  the change applies in memory and the result says it was not saved.
   function Write_Settings
     (Settings_Path : String;
      Settings      : Files.Settings.Settings_Model)
      return Files.Settings.Settings_Write_Result is
   begin
      if Settings.Persistence_Refused then
         return
           (Success   => True,
            Durable   => False,
            Path      => To_Unbounded_String (Settings_Path),
            Error_Key => To_Unbounded_String ("error.settings.not_persisted"));
      elsif Settings_Path = "" then
         return (Success => True, Durable => True, Path => Null_Unbounded_String, Error_Key => Null_Unbounded_String);
      end if;
      return Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Settings));
   end Write_Settings;

   --  The one save policy for a settings change, wherever it came from: the
   --  change is applied already and kept for the session; a file that would
   --  not load again (Loadable) is not written; a write that fails or is not
   --  durable is reported in the window's error line. (A settings command's
   --  own durable save clears that line; a save following another operation
   --  leaves that operation's message.)
   function Persisted
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result
   is
   begin
      if not Files.Settings.Loadable (Settings) then
         Files.Model.Set_Error (Model, "error.settings.full");
         return
           (Success   => False,
            Durable   => False,
            Path      => To_Unbounded_String (Settings_Path),
            Error_Key => To_Unbounded_String ("error.settings.full"));
      end if;
      declare
         Saved : constant Files.Settings.Settings_Write_Result := Write_Settings (Settings_Path, Settings);
      begin
         if not Saved.Success or else not Saved.Durable then
            --  Applied, but not saved (or not safely): say so.
            Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         end if;
         return Saved;
      end;
   end Persisted;

   --  What a settings commit did: the write's result, and whether Updated
   --  said something new and is now the live settings.
   type Commit_Outcome is record
      Saved    : Files.Settings.Settings_Write_Result;
      Accepted : Boolean := False;
   end record;

   --  The one settings commit, comparing Updated with Settings once: an
   --  unchanged one counts as saved, one that would make loadable settings
   --  unloadable is refused, and any other replaces Settings, is noted on
   --  the window's settings revision, and is persisted.
   function Commit
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Commit_Outcome is
   begin
      if Files.Settings.Same_Content (Updated, Settings) then
         return
           (Saved    =>
              (Success => True, Durable => True, Path => To_Unbounded_String (Settings_Path),
               Error_Key => Null_Unbounded_String),
            Accepted => False);
      --  Refused when it is this change that makes them unloadable: if they
      --  already were, refusing every later change (a zoom, a toggle) would
      --  only lock the user out; Persisted then still writes nothing.
      elsif not Files.Settings.Loadable (Updated) and then Files.Settings.Loadable (Settings) then
         Files.Model.Set_Error (Model, "error.settings.full");
         return
           (Saved    =>
              (Success   => False,
               Durable   => False,
               Path      => To_Unbounded_String (Settings_Path),
               Error_Key => To_Unbounded_String ("error.settings.full")),
            Accepted => False);
      end if;
      declare
         Before : constant Files.Settings.Settings_Model := Settings;
      begin
         Settings := Updated;
         Files.Model.Note_Settings_Changed (Model);
         Follow_Favorites (Model, Before, Settings);
      end;
      return (Saved => Persisted (Model, Settings, Settings_Path), Accepted => True);
   end Commit;

   function Commit_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result is
   begin
      return Commit (Model, Settings, Updated, Settings_Path).Saved;
   end Commit_Settings;

   procedure Commit_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String;
      Accepted      : out Boolean) is
   begin
      Accepted := Commit (Model, Settings, Updated, Settings_Path).Accepted;
   end Commit_Settings;

   procedure Persist_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
   is
      Saved : constant Files.Settings.Settings_Write_Result := Persisted (Model, Settings, Settings_Path);
      pragma Unreferenced (Saved);
   begin
      null;
   end Persist_Settings;

   function Make_Result
     (Status    : Controller_Status;
      Command   : Files.Commands.Command_Id := Files.Commands.No_Command;
      Operation : Files.Operation_Results.Operation_Result := Empty_Operation)
      return Controller_Result is
   begin
      return
        (Status    => Status,
         Command   => Command,
         Operation => Operation,
         others    => <>);
   end Make_Result;

   --  The result of an action that may have left the model as it was:
   --  ignored when Unchanged, otherwise Changed.
   function Changed_Result
     (Unchanged : Boolean;
      Changed   : Controller_Status := Controller_Command_Executed)
      return Controller_Result
   is (Make_Result (if Unchanged then Controller_Ignored else Changed));

   --  The result of an action that moved a position or count from Old to
   --  Current: ignored when it stayed put, otherwise Changed.
   function Changed_Result
     (Old, Current : Natural;
      Changed      : Controller_Status := Controller_Command_Executed)
      return Controller_Result
   is (Changed_Result (Current = Old, Changed));

   function Successful_Command_Result
     (Command : Files.Commands.Command_Id)
      return Controller_Result
   is
      Operation : Files.Operation_Results.Operation_Result := Empty_Operation;
   begin
      Operation.Status := Files.Operation_Results.Operation_Success;
      return Make_Result (Controller_Command_Executed, Command, Operation);
   end Successful_Command_Result;

   --  What Close_Overlay_Command does, by its key (Escape unless rebound)
   --  or as a command: the overlay Escape closes on top is closed, else a
   --  focused field or an edit is cancelled, else there is nothing to do.
   function Close_Top_Or_Cancel
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Overlay : Files.Model.Input_Overlay;
   begin
      if Files.Model.Escape_Overlay (Model, Overlay) then
         Files.Model.Close_Overlay (Model, Overlay);
      elsif Files.Model.Focus (Model) /= Files.Types.Focus_None
        or else Files.Model.Rename.Is_Active (Model)
        or else Files.Model.Temporary_Item_Is_Active (Model)
      then
         Files.Model.Cancel_Focus_Or_Edit (Model);
      else
         return Make_Result (Controller_Ignored, Files.Commands.Close_Overlay_Command);
      end if;
      return Successful_Command_Result (Files.Commands.Close_Overlay_Command);
   end Close_Top_Or_Cancel;

   function Confirm_Tree_Pick
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result
   is
      Mode : constant Files.Model.Tree_Pick_Mode := Files.Model.Tree_Panel.Pick_Mode_Of (Model);
   begin
      --  An empty target can occur while a newly seeded tree has no visible
      --  rows: the picker stays open rather than turning Choose into Cancel.
      if not Files.Model.Tree_Panel.Pick_Is_Active (Model)
        or else Mode = Files.Model.Pick_None
        or else Files.Model.Tree_Panel.Pick_Target (Model) = ""
      then
         return Make_Result (Controller_Ignored);
      end if;
      declare
         Command : constant Files.Commands.Command_Id :=
           (if Mode = Files.Model.Pick_Move then Files.Commands.Move_To_Command else Files.Commands.Copy_To_Command);
         Op      : constant Files.Operation_Results.Operation_Result :=
           Files.Operations.Begin_Paste_To
             (Model, Settings, Files.Model.Tree_Panel.Pick_Sources (Model),
              Files.Model.Tree_Panel.Pick_Target (Model),
              (if Mode = Files.Model.Pick_Move then Files.File_System.Drop_Move else Files.File_System.Drop_Copy));
      begin
         if Op.Status /= Files.Operation_Results.Operation_Success then
            return Make_Result (Controller_Ignored, Command, Op);
         end if;
         Files.Model.Tree_Panel.End_Pick (Model);
         return Make_Result (Controller_Command_Executed, Command, Op);
      end;
   end Confirm_Tree_Pick;

   --  Open root Root_Index of the root selector: what a click on it and the
   --  open-selected command both do. The command may come from the palette,
   --  open over the selector, so the overlay checks are the caller's.
   function Open_Root
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Root_Index : Positive)
      return Controller_Result;

   function Disabled_Command_Result
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model)
      return Controller_Result
 is separate;

   procedure Scroll_Palette_Selection
     (Model : in out Files.Model.Window_Model;
      Lines : Integer) is
   begin
      --  Wheel: a positive Lines advances (scrolls down) the selection.
      Files.Model.Command_Palette.Move_Selection (Model, Lines);
   end Scroll_Palette_Selection;

   procedure Replace_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String) is
   begin
      case Files.Model.Focus (Model) is
         when Files.Types.Focus_Path_Input =>
            Files.Model.Set_Path_Input_Text (Model, Text);
         when Files.Types.Focus_Filter_Input =>
            Files.Model.Set_Filter (Model, Text);
         when Files.Types.Focus_Rename_Input =>
            Files.Model.Rename.Set_Text (Model, Text);
         when Files.Types.Focus_Command_Palette =>
            Files.Model.Command_Palette.Set_Query (Model, Text);
         when Files.Types.Focus_Settings_Input =>
            Files.Model.Settings_Pane.Set_Focused_Value (Model, Text);
            declare
               Saved : constant Boolean :=
                 Files.Settings_Form.Apply (Model, Files.Model.Settings_Pane.Take_Change (Model));
               pragma Unreferenced (Saved);
            begin
               null;  --  text edits update the draft but persist on commit
            end;
         when Files.Types.Focus_Ownership_Input =>
            Files.Model.Set_Ownership_Input_Text (Model, Text);
         when Files.Types.Focus_None =>
            null;
      end case;
   end Replace_Focused_Text;

   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result
 is separate;

   type Delete_Direction is (Delete_Backward, Delete_Forward);

   --  Delete the character, or By_Word the word, before (Delete_Backward) or
   --  after the caret of the focused text input; for rename, at every
   --  synchronized caret. Both go through Guikit.Utf8.Editing.Delete_At.
   --
   --  @param Model Window model to update.
   --  @param Direction Which side of the caret to delete.
   --  @param By_Word Whether to delete to a word boundary.
   --  @return Controller result indicating whether text changed.
   function Delete_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Direction : Delete_Direction;
      By_Word   : Boolean)
      return Controller_Result
 is separate;

   --  Forward declaration: the reveal helper is defined alongside the other
   --  navigation helpers below, but Run_Command routes to it above them.
   function Reveal_Selected_Item
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result;

   --  Run an enabled command that needs no settings path: the one table
   --  of what each command does. Its callers have checked enablement.
   function Run_Command
     (Id        : Files.Commands.Non_Settings_Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result
 is separate;

   function Execute_Non_Settings_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result is
   begin
      if not Files.Commands.Status.Is_Enabled (Id, Model) then
         return Disabled_Command_Result (Id, Model);
      elsif Files.Commands.Requires_Settings_Path (Id) then
         --  Reported, not applied: changing the settings file needs its path.
         return Make_Result (Controller_Needs_Settings_Path, Id);
      end if;
      return Run_Command (Id, Model, Settings, Modifiers);
   end Execute_Non_Settings_Command;

   --  Capture the live Files.Commands override table into the settings model so a
   --  save persists the current keymap. The [shortcuts] section is thus always a
   --  mirror of the effective overrides; an explicit unbind persists as an empty
   --  combo (Shortcut_Text of an absent shortcut is "").
   procedure Store_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model) is
   begin
      Settings.Shortcut_Overrides.Clear;
      for Id in Files.Commands.Registered_Command_Id loop
         declare
            Is_Set : Boolean;
            Value  : constant Files.Commands.Shortcut := Files.Commands.Shortcut_Override (Id, Is_Set);
         begin
            if Is_Set then
               Settings.Shortcut_Overrides.Append
                 (Files.Settings.Shortcut_Override'
                    (Command => To_Unbounded_String (Files.Commands.Identifier (Id)),
                     Combo   => To_Unbounded_String (Files.Commands.Shortcut_Text (Value))));
            end if;
         end;
      end loop;
   end Store_Shortcut_Overrides;

   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
 is separate;

   --  A settings command's change, through Commit_Settings, with the save's
   --  outcome in the result. Reload re-lists the directory after an accepted
   --  change, for a setting that changes which items are listed.
   function Apply_Settings_Change
     (Id            : Files.Commands.Command_Id;
      Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String;
      Reload        : Boolean := False)
      return Controller_Result
   is
      Operation : Files.Operation_Results.Operation_Result := Empty_Operation;
      Outcome   : constant Commit_Outcome := Commit (Model, Settings, Updated, Settings_Path);
      Saved     : Files.Settings.Settings_Write_Result renames Outcome.Saved;
   begin
      --  List again only after a change that was taken (Settings now holds
      --  Updated); an unchanged or refused one leaves the listing as it is.
      if Reload and then Outcome.Accepted then
         Operation := Files.Operations.Refresh (Model, Settings);
      end if;
      if Operation.Status = Files.Operation_Results.Operation_Failed then
         return Make_Result (Controller_Command_Executed, Id, Operation);
      end if;

      --  A write that went through clears what an earlier one reported; a
      --  change that wrote nothing (unchanged, or refused) leaves the error
      --  line alone.
      if Outcome.Accepted and then Saved.Success and then Saved.Durable then
         Files.Model.Set_Error (Model, "");
      end if;
      Operation.Status :=
        (if Saved.Success then Files.Operation_Results.Operation_Success else Files.Operation_Results.Operation_Failed);
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Saved.Error_Key;
      return Make_Result (Controller_Command_Executed, Id, Operation);
   end Apply_Settings_Change;

   function Toggle_Hidden_Files
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Updated : Files.Settings.Settings_Model := Settings;
   begin
      Updated.Show_Hidden_Files := not Updated.Show_Hidden_Files;
      return
        Apply_Settings_Change
          (Files.Commands.Toggle_Hidden_Files_Command, Model, Settings, Updated, Settings_Path, Reload => True);
   end Toggle_Hidden_Files;

   --  Flip the Show_File_Extensions setting and persist it. Display-only: the
   --  item list is unchanged, so there is no directory reload; the next
   --  Build_Snapshot carries the new flag and rebuilds the frame on its own.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model whose extension flag is flipped.
   --  @param Settings_Path Central settings file path.
   --  @return Controller result with persistence operation details.
   function Toggle_Show_Extensions
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Updated : Files.Settings.Settings_Model := Settings;
   begin
      Updated.Show_File_Extensions := not Updated.Show_File_Extensions;
      return
        Apply_Settings_Change
          (Files.Commands.Toggle_Show_Extensions_Command, Model, Settings, Updated, Settings_Path);
   end Toggle_Show_Extensions;

   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
 is separate;

   function Apply_Settings_Command
     (Id            : Files.Commands.Settings_Command_Id;
      Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is separate;

   function Complete_Settings_Command
     (Reported      : Controller_Result;
      Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result is
   begin
      if Reported.Status = Controller_Needs_Settings_Path then
         return Apply_Settings_Command (Reported.Command, Model, Settings, Settings_Path);
      end if;
      return Reported;
   end Complete_Settings_Command;

   function Handle_Search_Scope_Toggle
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result
 is separate;

   function Handle_Permission_Toggle
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Bit      : Natural)
      return Controller_Result is
   begin
      if not Files.Model.Info_Pane_Is_Open (Model)
        or else Files.Model.Input_Owning_Overlay_Is_Open (Model)
        or else Bit > 8
      then
         return Make_Result (Controller_Ignored);
      end if;
      return Make_Result
        (Controller_Command_Executed,
         Operation => Files.Operations.Toggle_Permission_Bit (Model => Model, Bit => Bit, Settings => Settings));
   end Handle_Permission_Toggle;

   function Handle_Ownership_Edit
     (Model : in out Files.Model.Window_Model;
      Group : Boolean)
      return Controller_Result is
   begin
      if not Files.Model.Info_Pane_Is_Open (Model)
        or else Files.Model.Input_Owning_Overlay_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;
      Files.Operations.Focus_Ownership_Input (Model, Editing_Group => Group);
      return Make_Result (Controller_Text_Updated);
   end Handle_Ownership_Edit;

   function Handle_Conflict_Choice
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Choice   : Files.Operations.Conflict_Choice)
      return Controller_Result is
   begin
      if not Files.Model.Pasting.Conflict_Is_Active (Model) then
         return Make_Result (Controller_Ignored);
      end if;
      return Make_Result
        (Controller_Command_Executed,
         Operation =>
           Files.Operations.Resolve_Paste_Conflict
             (Model     => Model,
              Settings  => Settings,
              Choice    => Choice,
              Apply_All => Files.Model.Pasting.Conflict_Apply_All (Model)));
   end Handle_Conflict_Choice;

   function Handle_Conflict_Apply_All_Toggle
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      if not Files.Model.Pasting.Conflict_Is_Active (Model) then
         return Make_Result (Controller_Ignored);
      end if;
      Files.Model.Pasting.Toggle_Conflict_Apply_All (Model);
      return Make_Result (Controller_Command_Executed);
   end Handle_Conflict_Apply_All_Toggle;

   function Handle_Paste_Cancel
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result is
   begin
      if not Files.Model.Foreground_Job_Is_Active (Model) then
         return Make_Result (Controller_Ignored);
      end if;
      Files.Foreground_Jobs.Cancel (Model);
      return Make_Result
        (Controller_Command_Executed, Operation => Files.Foreground_Jobs.Advance (Model, Settings, 1));
   end Handle_Paste_Cancel;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Controller_Result
   is
      Operation : constant Files.Operation_Results.Operation_Result :=
        Files.Operations.Select_Root (Model, Settings, Root_Path);
   begin
      return Make_Result (Controller_Command_Executed, Files.Commands.Select_Drive_Command, Operation);
   end Select_Root;

   --  Reveal the single selected item by navigating to its parent directory and
   --  selecting it there, as a file favorite's click does. When the parent is
   --  empty or already the current directory the reveal is a safe no-op that
   --  reports success without navigating.
   function Reveal_Selected_Item
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result
   is
      Items : constant Files.Items.Item_Vectors.Vector :=
        Files.Model.Selection.Selected_Items (Model, Limit => 2);
   begin
      if Natural (Items.Length) /= 1 then
         return Make_Result (Controller_Ignored, Files.Commands.Open_Containing_Folder_Command);
      end if;

      declare
         Path   : constant String := To_String (Items.First_Element.Full_Path);
         Parent : constant String := Files.File_System.Parent_Directory (Path);
      begin
         if Parent = "" or else Parent = Files.Model.Current_Path (Model) then
            --  Already in the containing folder (or no parent): nothing to do.
            return Make_Result (Controller_Command_Executed, Files.Commands.Open_Containing_Folder_Command);
         end if;
         return Make_Result
           (Controller_Command_Executed,
            Files.Commands.Open_Containing_Folder_Command,
            Files.Operations.Navigate_And_Select (Model, Settings, Path));
      end;
   end Reveal_Selected_Item;

   function Open_Root
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Root_Index : Positive)
      return Controller_Result is
   begin
      Files.Model.Root_Selector.Set_Selected_Index (Model, Root_Index);
      declare
         Path : constant String := Files.Model.Root_Selector.Path (Model, Root_Index);
         Kind : constant Files.File_System.Root_Kind :=
           Files.Model.Root_Selector.Kind (Model, Root_Index);
      begin
         --  A favorite may target a file or a stale path; ordinary roots are
         --  always directories and take the direct navigation path.
         if Kind = Files.File_System.Root_Favorite then
            case Files.Operations.Classify_Favorite (Path) is
               when Files.Operations.Favorite_Stale =>
                  --  Broken favorite: skip the click without raising so a stale
                  --  entry can never crash the selector.
                  return Make_Result (Controller_Ignored);
               when Files.Operations.Favorite_File =>
                  --  The folder opens with the file selected.
                  declare
                     Operation : constant Files.Operation_Results.Operation_Result :=
                       Files.Operations.Navigate_And_Select (Model, Settings, Path);
                  begin
                     return Make_Result
                       ((if Operation.Status = Files.Operation_Results.Operation_Disabled
                         then Controller_Ignored
                         else Controller_Command_Executed),
                        Files.Commands.Open_Selected_Root_Command,
                        Operation);
                  end;
               when Files.Operations.Favorite_Folder =>
                  null;
            end case;
         end if;

         declare
            Operation : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Path);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.Open_Selected_Root_Command, Operation);
         end;
      end;
   end Open_Root;

   function Handle_Root_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Root_Index : Natural)
      return Controller_Result is
   begin
      if not Files.Model.Root_Selector.Is_Open (Model)
        or else Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Types.Root_Selector_Overlay)
        or else Root_Index = 0
        or else Root_Index > Files.Model.Root_Selector.Count (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;

      return Open_Root (Model, Settings, Positive (Root_Index));
   end Handle_Root_Click;

   function Handle_Breadcrumb_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Segment_Index : Natural)
      return Controller_Result
   is
      Segments : constant Files.Breadcrumbs.Segment_Vectors.Vector :=
        Files.Breadcrumbs.Segments (Files.Model.Current_Path (Model));
   begin
      if Files.Model.Input_Owning_Overlay_Is_Open (Model)
        or else Segment_Index = 0
        or else Segment_Index > Natural (Segments.Length)
      then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Target : constant String :=
           To_String (Segments.Element (Positive (Segment_Index)).Ancestor_Path);
      begin
         if Target = "" then
            return Make_Result (Controller_Ignored);
         end if;

         declare
            Operation : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Target);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
         end;
      end;
   end Handle_Breadcrumb_Click;

   --  Whether a tree click on Node_Index is taken: the tree is open, no
   --  input-owning overlay but the destination picker (which is the tree
   --  itself) covers it, and the node exists.
   function Tree_Node_Accepts_Click
     (Model      : Files.Model.Window_Model;
      Node_Index : Natural)
      return Boolean is
     (Files.Model.Tree_Panel.Is_Open (Model)
      and then not Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Types.Tree_Pick_Overlay)
      and then Node_Index in 1 .. Files.Model.Tree_Panel.Node_Count (Model));

   function Toggle_Tree_Node
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural)
      return Controller_Result is
   begin
      if not Tree_Node_Accepts_Click (Model, Node_Index) then
         return Make_Result (Controller_Ignored);
      end if;
      if not Files.Model.Tree_Panel.Node_Is_Expanded (Model, Node_Index) then
         Files.Operations.Load_Tree_Children (Model, Settings, Node_Index);
      end if;
      Files.Model.Tree_Panel.Toggle_Expanded (Model, Node_Index);
      return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Empty_Operation);
   end Toggle_Tree_Node;

   function Activate_Tree_Node
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural)
      return Controller_Result
   is separate;

   --  Launch the chosen "Open With" application on the stored target paths, then
   --  close the palette. A detached launch has no application exit status, but
   --  preflight and process creation are still observable and are reported.
   function Launch_Application_Result
     (Model : in out Files.Model.Window_Model;
      App   : Files.Desktop_Applications.Application)
      return Controller_Result
   is
      Targets : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Command_Palette.Open_With_Targets (Model);
   begin
      Files.Model.Command_Palette.Close (Model);
      return Make_Result
        (Controller_Command_Executed,
         Files.Commands.Open_With_Command,
         Files.Operations.Launch_Application (Model, App, Targets));
   end Launch_Application_Result;

   --  Act on the palette's highlighted command (from Command_Palette.Selected_Id):
   --  launch the application in Open-With mode, otherwise execute the command,
   --  closing the palette on success (except Open_With, which re-opens the
   --  palette in application-picker mode).
   function Activate_Palette_Command
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result
   is
      Id : constant Natural := Files.Model.Command_Palette.Selected_Id (Model);
   begin
      if Files.Model.Command_Palette.Mode_Of (Model) = Files.Model.Palette_Open_With then
         declare
            Apps : constant Files.Desktop_Applications.Application_Vectors.Vector :=
              Files.Model.Command_Palette.Open_With_Applications (Model);
         begin
            if Id in 1 .. Natural (Apps.Length) then
               return Launch_Application_Result (Model, Apps.Element (Id));
            end if;
            return Make_Result (Controller_Ignored);
         end;
      end if;

      declare
         Command : constant Files.Commands.Command_Id := Files.Command_Palette.Selected_Command (Model);
         Result  : Controller_Result;
      begin
         if Command = Files.Commands.No_Command then
            return Make_Result (Controller_Ignored);
         end if;
         Result := Execute_Non_Settings_Command (Command, Model, Settings, Modifiers);
         if Result.Status /= Controller_Ignored
           and then Command /= Files.Commands.Open_With_Command
         then
            Files.Model.Command_Palette.Close (Model);
         end if;
         return Result;
      end;
   end Activate_Palette_Command;

   function Handle_Item_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Visible_Index : Natural;
      Activate      : Boolean := False;
      Modifiers     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result is separate;

   --  External file drops have no overlay-specific destination, so every
   --  input-owning overlay blocks them rather than allowing a hidden filesystem
   --  mutation in the current directory.
   function Accepts_Drop_Import (Model : Files.Model.Window_Model) return Boolean is
     (not Files.Model.Input_Owning_Overlay_Is_Open (Model));

   function Handle_Drop_Import
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Source_Paths : Files.Types.String_Vectors.Vector;
      Mode         : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy)
      return Controller_Result
   is
      --  Route drops through the paste engine so a drag-and-drop import gets the
      --  same conflict dialog and resumable progress/cancel overlay as clipboard
      --  paste. From_Clipboard => False keeps a dropped move from clearing an
      --  unrelated clipboard selection on finalize.
      Operation : Files.Operation_Results.Operation_Result;
   begin
      if not Accepts_Drop_Import (Model) then
         return Make_Result (Controller_Ignored);
      end if;
      Operation := Files.Operations.Begin_Paste
        (Model, Settings, Source_Paths, Mode, From_Clipboard => False);
      return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
   end Handle_Drop_Import;

   procedure Import_Pending_Drops
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Source   : in out Files.Drop_Events.Drop_Event_Source)
   is
      Drops : Files.Types.String_Vectors.Vector;
      Mode  : Files.File_System.Drop_Import_Mode;
   begin
      if Files.Drop_Events.Has_Pending (Source) and then Accepts_Drop_Import (Model) then
         Files.Drop_Events.Take (Source, Drops, Mode);
         declare
            Result : constant Controller_Result := Handle_Drop_Import (Model, Settings, Drops, Mode);
            pragma Unreferenced (Result);
         begin
            null;
         end;
      end if;
   end Import_Pending_Drops;

   function Scroll_Info_Result
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result
   is
      Old_Lines : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
   begin
      Files.Model.Scroll_Info_Pane (Model, Lines);
      return Changed_Result (Old_Lines, Files.Model.Info_Pane_Scroll_Lines (Model));
   end Scroll_Info_Result;

   function Scroll_Tree_Result
     (Model : in out Files.Model.Window_Model;
      Rows  : Integer)
      return Controller_Result
   is
      Old_Rows : constant Natural := Files.Model.Tree_Panel.Scroll_Rows (Model);
   begin
      Files.Model.Tree_Panel.Scroll (Model, Rows);
      return Changed_Result (Old_Rows, Files.Model.Tree_Panel.Scroll_Rows (Model));
   end Scroll_Tree_Result;

   function Scroll_Settings_Result
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result is
   begin
      Files.Model.Settings_Pane.Scroll (Model, Lines);
      return Make_Result (Controller_Command_Executed);
   end Scroll_Settings_Result;

   function Scroll_Main_Result
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result
   is
      Old_Lines : constant Natural := Files.Model.Main_View_Scroll_Lines (Model);
   begin
      Files.Model.Scroll_Main_View (Model, Lines);
      return Changed_Result (Old_Lines, Files.Model.Main_View_Scroll_Lines (Model));
   end Scroll_Main_Result;

   function Handle_Scroll
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result
   is
      Top : Files.Model.Input_Overlay;
   begin
      if Lines = 0 then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Topmost_Overlay (Model, Top) then
         --  The overlay on top takes the wheel (Files.Types.Overlay_Stack).
         --  Without cursor geometry only the palette and the settings pane
         --  have something to scroll; every other overlay contains it,
         --  matching the pointer translator.
         case Top is
            when Files.Types.Command_Palette_Overlay =>
               if Files.Model.Command_Palette.Result_Count (Model) = 0 then
                  return Make_Result (Controller_Ignored);
               end if;
               Scroll_Palette_Selection (Model, Lines);
               return Make_Result (Controller_Palette_Updated);
            when Files.Types.Settings_Pane_Overlay =>
               return Scroll_Settings_Result (Model, Lines);
            when Files.Types.Foreground_Job_Overlay
               | Files.Types.Paste_Conflict_Overlay
               | Files.Types.Root_Selector_Overlay
               | Files.Types.Sort_Menu_Overlay
               | Files.Types.Context_Menu_Overlay
               | Files.Types.Label_Picker_Overlay
               | Files.Types.Quick_Look_Overlay
               | Files.Types.Tree_Pick_Overlay =>
               return Make_Result (Controller_Ignored);
         end case;
      elsif Files.Model.Info_Pane_Is_Open (Model) then
         return Scroll_Info_Result (Model, Lines);
      end if;

      return Scroll_Main_Result (Model, Lines);
   end Handle_Scroll;

   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Events.Scroll_Target;
      Lines  : Integer)
      return Controller_Result is separate;

   function Handle_Text_Click
     (Model           : in out Files.Model.Window_Model;
      Target          : Files.Types.Focus_Target;
      Cursor_Position : Natural;
      Item_Index      : Natural := 0)
      return Controller_Result
 is separate;

   --  Drain the settings panel's emitted change into the draft. A value change to
   --  a toggle/choice/number or an add/remove auto-saves (persist + refresh),
   --  which needs the settings path (Complete_Settings_Command); text edits
   --  are applied but saved on commit.
   function Applied_Settings_Change
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      if Files.Settings_Form.Apply (Model, Files.Model.Settings_Pane.Take_Change (Model)) then
         return Make_Result (Controller_Needs_Settings_Path, Files.Commands.Save_Settings_Command);
      else
         return Make_Result (Controller_Text_Updated);
      end if;
   end Applied_Settings_Change;

   --  Consume a key while a settings Shortcut field is armed for capture: Escape
   --  cancels, an unmodified Backspace/Delete unbinds, any other representable
   --  chord is committed. The committed change flows through Applied_Settings_Change
   --  (which rebinds the live keymap and auto-saves).
   function Capture_Settings_Shortcut
     (Model     : in out Files.Model.Window_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result is separate;

   --  Move the settings pane to the next/previous section tab, wrapping. This is
   --  the only keyboard path between sections -- Up/Down move field focus within
   --  the active section, never across tabs.
   procedure Cycle_Settings_Section (Model : in out Files.Model.Window_Model; Forward : Boolean) is
      Count  : constant Natural := Files.Model.Settings_Pane.Section_Count (Model);
      Active : constant Natural := Files.Model.Settings_Pane.Active_Section (Model);
   begin
      if Count <= 1 then
         return;
      elsif Forward then
         Files.Model.Settings_Pane.Set_Active_Section (Model, (if Active >= Count then 1 else Active + 1));
      else
         Files.Model.Settings_Pane.Set_Active_Section (Model, (if Active <= 1 then Count else Active - 1));
      end if;
   end Cycle_Settings_Section;

   function Handle_Settings_Click
     (Model : in out Files.Model.Window_Model;
      X     : Integer;
      Y     : Integer)
      return Controller_Result is
   begin
      if not Files.Model.Settings_Pane.Is_Open (Model)
        or else Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Types.Settings_Pane_Overlay)
        or else not Files.Model.Settings_Pane.Click (Model, X, Y)
      then
         return Make_Result (Controller_Ignored);
      end if;
      return Applied_Settings_Change (Model);
   end Handle_Settings_Click;

   function Commit_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set)
      return Controller_Result
 is separate;

   function Root_Selection_Result
     (Model     : in out Files.Model.Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Root_Selector.Selected_Index (Model);
   begin
      Files.Model.Root_Selector.Move_Selection (Model, Direction);
      return Changed_Result (Old_Index, Files.Model.Root_Selector.Selected_Index (Model), Controller_Selection_Moved);
   end Root_Selection_Result;

   function Root_Jump_Result
     (Model : in out Files.Model.Window_Model;
      Index : Natural)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Root_Selector.Selected_Index (Model);
   begin
      Files.Model.Root_Selector.Set_Selected_Index (Model, Index);
      return Changed_Result (Old_Index, Files.Model.Root_Selector.Selected_Index (Model), Controller_Selection_Moved);
   end Root_Jump_Result;

   function Step_Selection_Result
     (Model     : in out Files.Model.Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
   begin
      Files.Model.Selection.Move (Model, Direction);
      return Changed_Result (Old_Index, Files.Model.Selection.Selected_Index (Model), Controller_Selection_Moved);
   end Step_Selection_Result;

   function First_Selection_Result
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
   begin
      Files.Model.Selection.Select_First_Visible (Model);
      return Changed_Result (Old_Index, Files.Model.Selection.Selected_Index (Model), Controller_Selection_Moved);
   end First_Selection_Result;

   function Last_Selection_Result
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
   begin
      Files.Model.Selection.Select_Last_Visible (Model);
      return Changed_Result (Old_Index, Files.Model.Selection.Selected_Index (Model), Controller_Selection_Moved);
   end Last_Selection_Result;

   function Page_Selection_Result
     (Model : in out Files.Model.Window_Model;
      Down  : Boolean)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
   begin
      Files.Model.Selection.Move_By_Page (Model, Files.Model.Selection.Page_Rows (Model), Down);
      return Changed_Result (Old_Index, Files.Model.Selection.Selected_Index (Model), Controller_Selection_Moved);
   end Page_Selection_Result;

   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result
 is separate;

end Files.Controller;
