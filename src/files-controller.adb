with Files.Operations.Navigation;
with Files.Operations.Opening;
with Files.Operations.Metadata;
with Files.Operations.Tree;
with Files.Settings.Drafts;
with Files.Model.Ownership_Input;
with Files.Model.Info_Pane;
with Files.Model.Filtering;
with Files.Overlays.Settings_Form;
with Files.IO.Fs_Primitives;
with Files.Job_Drivers.Foreground;
with Files.Items;
with Files.Commands.Status;
with Ada.Strings.Unbounded;

with Guikit.Settings_Panel;

with Files.Desktop_Applications;
with Files.Breadcrumbs;
with Files.Folder_Tree;
with Guikit.Bidi;
with Guikit.Utf8.Editing;
with Files.Overlays.Command_Palette;
with Files.Model.Command_Palette;
with Files.Model.Root_Selector;
with Files.Model.Settings_Pane;
with Files.Model.Tree_Panel;
with Files.Model.Pasting;
with Files.Model.Rename;
with Files.Model.Selection;
with Files.Settings.Open_Actions;
with Files.Settings.Path_References;
with Files.Settings.Storage;

package body Files.Controller is
   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Input_Actions.Grid_Move;
   use type Files.Input_Actions.Input_Action_Kind;
   use type Files.Input_Actions.Scroll_Target;
   use type Files.File_System_Types.Root_Kind;
   use type Files.Model.Palette_Mode;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Operation_Results.Operation_Status;
   use type Files.UI_Types.Focus_Target;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;

   function Empty_Operation return Files.Operation_Results.Operation_Result is
   begin
      return
        (Status    => Files.Operation_Results.Operation_Disabled,
         Error_Key => Null_Unbounded_String,
         Path      => Null_Unbounded_String,
         Action    => Files.Settings.Open_Actions.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
         others    => <>);
   end Empty_Operation;

   --  Favorites are folder tree roots: a tree already seeded is seeded again
   --  when the favorites list differs between Before and Settings. Every
   --  settings commit does this; a caller that replaces the settings another
   --  way (adopting another window's) calls it.
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
         Files.Operations.Tree.Seed_Tree (Model, Settings);
      end if;
   end Follow_Favorites;

   procedure Refresh_Open_Pane
     (Model    : in out Files.Model.Window_Model;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      if Files.Model.Settings_Pane.Is_Open (Model) then
         declare
            use type Files.Settings.Settings_Draft;
            Shown     : constant Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
            Refreshed : constant Files.Settings.Settings_Draft :=
              Files.Settings.Drafts.Refresh_Draft (Shown, Before, Settings);
         begin
            if Refreshed /= Shown then
               Files.Overlays.Settings_Form.Set_Draft (Model, Refreshed);
            end if;
            --  A command that changed them saved Settings (another window's
            --  save is adopted the same way): the pane's next change is
            --  weighed against them.
            if not Files.Settings.Same_Content (Before, Settings) then
               Files.Overlays.Settings_Form.Mark_Saved (Model, Settings);
            end if;
         end;
      end if;
   end Refresh_Open_Pane;

   procedure Take_In_Settings
     (Model    : in out Files.Model.Window_Model;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model)
   is
      use type Files.Types.Sort_Field;
      use type Files.Settings.String_Maps.Map;
   begin
      Refresh_Open_Pane (Model, Before, Settings);
      --  Shortcuts are the process's, rebound in the other window; this
      --  window's palette listed them before.
      if Files.Model.Command_Palette.Is_Open (Model) then
         Files.Model.Command_Palette.Relist (Model);
      end if;
      Follow_Favorites (Model, Before, Settings);
      --  The sort is shared like the hidden filter: every window shows the
      --  order the settings hold, so a later command here never writes an
      --  order back that another window has since replaced. A sort alone
      --  needs no read, folder or search results alike.
      if Before.Sort_Field_Value /= Settings.Sort_Field_Value
        or else Before.Sort_Ascending /= Settings.Sort_Ascending
      then
         Files.Model.Apply_Sort (Model, Settings.Sort_Field_Value, Settings.Sort_Ascending);
      end if;
      --  Items carry the hidden filter and the type and icon they were
      --  classified with when the folder was read.
      if Before.Show_Hidden_Files = Settings.Show_Hidden_Files
        and then Before.Extension_Filetypes = Settings.Extension_Filetypes
        and then Before.Icon_Mappings = Settings.Icon_Mappings
      then
         null;
      elsif Files.Model.Filtering.Search_Results_Are_Active (Model) then
         --  Search results have no folder to read again (a reload would
         --  replace them with the folder): the new settings apply to them in
         --  place.
         Files.Model.Reapply_Listing_Settings
           (Model, Settings,
            Reclassify => Before.Extension_Filetypes /= Settings.Extension_Filetypes
                          or else Before.Icon_Mappings /= Settings.Icon_Mappings);
      else
         declare
            --  A reload that fails says so in the window's error line. The
            --  folder sizes stay: only a refresh the user asks for measures
            --  them again.
            Reloaded : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Refresh (Model, Settings, Measure_Again => False);
            pragma Unreferenced (Reloaded);
         begin
            null;
         end;
      end if;
   end Take_In_Settings;

   --  The settings refused as too big to load again, also said in the
   --  window's error line.
   function Settings_Full
     (Model         : in out Files.Model.Window_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result is
   begin
      Files.Model.Set_Error (Model, "error.settings.full");
      return Files.Settings.Storage.Full_Result (Settings_Path);
   end Settings_Full;

   --  Save already-applied settings (Files.Settings.Storage.Persist) and
   --  apply the outcome to this window: settings the save took in (another
   --  process's change, or a rebind not saved before) are made in force
   --  here as in the other windows, which take them from here; a write
   --  that fails or is not durable is reported in the error line while the
   --  change stays applied. (A settings command's own durable save clears
   --  that line; a save following another operation leaves that
   --  operation's message.)
   function Persisted
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Files.Settings.Settings_Write_Result
   is
      Before   : constant Files.Settings.Settings_Model := Settings;
      Taken_In : Boolean;
      Saved    : constant Files.Settings.Settings_Write_Result :=
        Files.Settings.Storage.Persist (Settings_Path, Settings, Taken_In);
   begin
      if Taken_In then
         Take_In_Settings (Model, Before, Settings);
         Files.Model.Note_Settings_Changed (Model);
      end if;
      if not Saved.Success or else not Saved.Durable then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
      end if;
      return Saved;
   end Persisted;

   --  What a settings commit did: the write's result, and whether Updated
   --  said something new and is now the live settings.
   type Commit_Outcome is record
      Saved    : Files.Settings.Settings_Write_Result;
      Accepted : Boolean := False;
   end record;

   --  The one settings commit (Files.Settings.Storage.Decide_Commit): an
   --  unchanged one counts as saved, a refused one is said in the error
   --  line, and any other replaces Settings, is noted on the window's
   --  settings revision, and is persisted.
   function Commit
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Updated       : Files.Settings.Settings_Model;
      Settings_Path : String)
      return Commit_Outcome is
   begin
      case Files.Settings.Storage.Decide_Commit (Settings, Updated) is
         when Files.Settings.Storage.Commit_Unchanged =>
            return (Saved => Files.Settings.Storage.Unchanged_Result (Settings_Path), Accepted => False);
         when Files.Settings.Storage.Commit_Refused =>
            return (Saved => Settings_Full (Model, Settings_Path), Accepted => False);
         when Files.Settings.Storage.Commit_Accepted =>
            declare
               Before : constant Files.Settings.Settings_Model := Settings;
            begin
               Settings := Updated;
               Files.Model.Note_Settings_Changed (Model);
               Follow_Favorites (Model, Before, Settings);
            end;
            return (Saved => Persisted (Model, Settings, Settings_Path), Accepted => True);
      end case;
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
      Settings      : in out Files.Settings.Settings_Model;
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
      if not Files.Model.Has_Something_To_Close (Model) then
         return Make_Result (Controller_Ignored, Files.Commands.Close_Overlay_Command);
      elsif Files.Model.Escape_Overlay (Model, Overlay) then
         Files.Model.Close_Overlay (Model, Overlay);
      else
         Files.Model.Cancel_Focus_Or_Edit (Model);
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
           Files.Operations.Paste.Begin_Paste_To
             (Model, Settings, Files.Model.Tree_Panel.Pick_Sources (Model),
              Files.Model.Tree_Panel.Pick_Target (Model),
              (if Mode = Files.Model.Pick_Move
                then Files.File_System_Types.Drop_Move
                else Files.File_System_Types.Drop_Copy));
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
         when Files.UI_Types.Focus_Path_Input =>
            Files.Model.Set_Path_Input_Text (Model, Text);
         when Files.UI_Types.Focus_Filter_Input =>
            Files.Model.Filtering.Set_Filter (Model, Text);
         when Files.UI_Types.Focus_Rename_Input =>
            Files.Model.Rename.Set_Text (Model, Text);
         when Files.UI_Types.Focus_Command_Palette =>
            Files.Model.Command_Palette.Set_Query (Model, Text);
            --  The query's matches are there before the next frame: a key
            --  queued behind the typing (Enter) acts on them.
            Files.Overlays.Command_Palette.Ensure_Listed (Model);
         when Files.UI_Types.Focus_Settings_Input =>
            Files.Model.Settings_Pane.Set_Focused_Value (Model, Text);
            declare
               Saved : constant Boolean :=
                 Files.Overlays.Settings_Form.Apply_Change (Model, Files.Model.Settings_Pane.Take_Change (Model));
               pragma Unreferenced (Saved);
            begin
               null;  --  a text edit updates the draft; Enter saves it (Commit_Focused_Text)
            end;
         when Files.UI_Types.Focus_Ownership_Input =>
            Files.Model.Ownership_Input.Set_Ownership_Input_Text (Model, Text);
         when Files.UI_Types.Focus_None =>
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

   --  Run a pure model command: one whose whole effect is window-model state.
   --  Only Run_Command calls this, after the command entry has checked
   --  Is_Enabled; every other command is executed there.
   --
   --  @param Id Pure command identifier.
   --  @param Model Window model to mutate.
   procedure Execute_Pure_Command
     (Id    : Files.Commands.Pure_Command_Id;
      Model : in out Files.Model.Window_Model)
   is separate;

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
      if not Files.Model.Info_Pane.Info_Pane_Is_Open (Model)
        or else Files.Model.Input_Owning_Overlay_Is_Open (Model)
        or else Bit > 8
      then
         return Make_Result (Controller_Ignored);
      end if;
      return Make_Result
        (Controller_Command_Executed,
         Operation => Files.Operations.Metadata.Toggle_Permission_Bit (Model => Model, Bit => Bit,
                                                                       Settings => Settings));
   end Handle_Permission_Toggle;

   function Handle_Ownership_Edit
     (Model : in out Files.Model.Window_Model;
      Group : Boolean)
      return Controller_Result is
   begin
      if not Files.Model.Info_Pane.Info_Pane_Is_Open (Model)
        or else Files.Model.Input_Owning_Overlay_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;
      Files.Operations.Metadata.Focus_Ownership_Input (Model, Editing_Group => Group);
      return Make_Result (Controller_Text_Updated);
   end Handle_Ownership_Edit;

   function Handle_Conflict_Choice
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Choice   : Files.Operations.Paste.Conflict_Choice)
      return Controller_Result is
   begin
      if not Files.Model.Pasting.Conflict_Is_Active (Model) then
         return Make_Result (Controller_Ignored);
      end if;
      return Make_Result
        (Controller_Command_Executed,
         Operation =>
           Files.Operations.Paste.Resolve_Paste_Conflict
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

   function Handle_Foreground_Job_Cancel
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result is
   begin
      if not Files.Model.Foreground_Job_Is_Active (Model) then
         return Make_Result (Controller_Ignored);
      end if;
      Files.Job_Drivers.Foreground.Cancel (Model);
      return Make_Result
        (Controller_Command_Executed, Operation => Files.Job_Drivers.Foreground.Advance (Model, Settings, 1));
   end Handle_Foreground_Job_Cancel;

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
         Parent : constant String := Files.IO.Fs_Primitives.Parent_Directory (Path);
      begin
         if Parent = "" or else Parent = Files.Model.Current_Path (Model) then
            --  Already in the containing folder (or no parent): nothing to do.
            return Make_Result (Controller_Command_Executed, Files.Commands.Open_Containing_Folder_Command);
         end if;
         return Make_Result
           (Controller_Command_Executed,
            Files.Commands.Open_Containing_Folder_Command,
            Files.Operations.Navigation.Navigate_And_Select (Model, Settings, Path));
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
         Kind : constant Files.File_System_Types.Root_Kind :=
           Files.Model.Root_Selector.Kind (Model, Root_Index);
      begin
         --  A favorite may target a file or a stale path; ordinary roots are
         --  always directories and take the direct navigation path.
         if Kind = Files.File_System_Types.Root_Favorite then
            case Files.Operations.Tree.Classify_Favorite (Path) is
               when Files.Operations.Tree.Favorite_Stale =>
                  --  Broken favorite: skip the click without raising so a stale
                  --  entry can never crash the selector.
                  return Make_Result (Controller_Ignored);
               when Files.Operations.Tree.Favorite_File =>
                  --  The folder opens with the file selected.
                  declare
                     Operation : constant Files.Operation_Results.Operation_Result :=
                       Files.Operations.Navigation.Navigate_And_Select (Model, Settings, Path);
                  begin
                     return Make_Result
                       ((if Operation.Status = Files.Operation_Results.Operation_Disabled
                         then Controller_Ignored
                         else Controller_Command_Executed),
                        Files.Commands.Open_Selected_Root_Command,
                        Operation);
                  end;
               when Files.Operations.Tree.Favorite_Folder =>
                  null;
            end case;
         end if;

         declare
            Operation : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Navigation.Select_Root (Model, Settings, Path);
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
        or else Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Root_Selector_Overlay)
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
              Files.Operations.Navigation.Select_Root (Model, Settings, Target);
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
      and then not Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Tree_Pick_Overlay)
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
         Files.Operations.Tree.Load_Tree_Children (Model, Settings, Node_Index);
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
         Files.Operations.Opening.Launch_Application (Model, App, Targets));
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
      Id : Natural;
   begin
      --  Enter may come before the first frame since the palette opened.
      Files.Overlays.Command_Palette.Ensure_Listed (Model);
      Id := Files.Model.Command_Palette.Selected_Id (Model);
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
         Command : constant Files.Commands.Command_Id := Files.Model.Command_Palette.Selected_Command (Model);
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

   function Handle_Item_Drop
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Target_Index : Natural;
      Modifiers    : Guikit.Input.Modifier_Set)
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
      Mode         : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy)
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
      Operation := Files.Operations.Paste.Begin_Paste
        (Model, Settings, Source_Paths, Mode, From_Clipboard => False);
      return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
   end Handle_Drop_Import;

   procedure Import_Pending_Drops
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Source   : in out Files.Drop_Events.Drop_Event_Source)
   is
      Drops : Files.Types.String_Vectors.Vector;
      Mode  : Files.File_System_Types.Drop_Import_Mode;
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

   --  How far Target is scrolled; 0 for a region without a position of
   --  its own (the palette scrolls its selection, Scroll_Palette_Selection).
   function Scroll_Position
     (Model  : Files.Model.Window_Model;
      Target : Files.Input_Actions.Scroll_Target)
      return Natural is
     (case Target is
         when Files.Input_Actions.Scroll_Main_View     => Files.Model.Main_View_Scroll_Lines (Model),
         when Files.Input_Actions.Scroll_Info_Pane     => Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model),
         when Files.Input_Actions.Scroll_Tree_Panel    => Files.Model.Tree_Panel.Scroll_Rows (Model),
         when Files.Input_Actions.Scroll_Settings_Pane => Files.Model.Settings_Pane.Scroll_Offset (Model),
         when Files.Input_Actions.No_Scroll_Target
            | Files.Input_Actions.Scroll_Command_Palette => 0);

   --  Scroll Target by Lines: executed when it moved, ignored when it was
   --  already at that end.
   function Scroll_Result
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Input_Actions.Scroll_Target;
      Lines  : Integer)
      return Controller_Result
   is
      Old : constant Natural := Scroll_Position (Model, Target);
   begin
      case Target is
         when Files.Input_Actions.Scroll_Main_View     => Files.Model.Scroll_Main_View (Model, Lines);
         when Files.Input_Actions.Scroll_Info_Pane     => Files.Model.Info_Pane.Scroll_Info_Pane (Model, Lines);
         when Files.Input_Actions.Scroll_Tree_Panel    => Files.Model.Tree_Panel.Scroll (Model, Lines);
         when Files.Input_Actions.Scroll_Settings_Pane => Files.Model.Settings_Pane.Scroll (Model, Lines);
         when Files.Input_Actions.No_Scroll_Target
            | Files.Input_Actions.Scroll_Command_Palette => null;
      end case;
      return Changed_Result (Old, Scroll_Position (Model, Target));
   end Scroll_Result;

   function Handle_Targeted_Scroll
     (Model  : in out Files.Model.Window_Model;
      Target : Files.Input_Actions.Scroll_Target;
      Lines  : Integer)
      return Controller_Result is separate;

   function Handle_Text_Click
     (Model           : in out Files.Model.Window_Model;
      Target          : Files.UI_Types.Focus_Target;
      Cursor_Position : Natural;
      Item_Index      : Natural := 0)
      return Controller_Result
 is separate;

   --  Drain the settings panel's emitted change into the draft. A toggle,
   --  choice, number or captured shortcut auto-saves (persist + refresh), as
   --  do reset, add and remove when the file would hold something new
   --  (Settings_Form.Apply); that needs the settings path
   --  (Complete_Settings_Command). Text edits are applied, and saved when
   --  Enter commits them (Commit_Focused_Text).
   function Applied_Settings_Change
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      if Files.Overlays.Settings_Form.Apply_Change (Model, Files.Model.Settings_Pane.Take_Change (Model)) then
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
        or else Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Settings_Pane_Overlay)
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

   function Root_Highlight_Result
     (Model      : in out Files.Model.Window_Model;
      Navigation : Files.Input_Actions.Grid_Navigation)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Root_Selector.Selected_Index (Model);
   begin
      case Navigation.Move is
         when Files.Input_Actions.Grid_Step =>
            Files.Model.Root_Selector.Move_Selection (Model, Navigation.Direction);
         when Files.Input_Actions.Grid_First =>
            Files.Model.Root_Selector.Set_Selected_Index (Model, 1);
         when Files.Input_Actions.Grid_Last =>
            Files.Model.Root_Selector.Set_Selected_Index (Model, Files.Model.Root_Selector.Count (Model));
         --  The selector shows every root at once: there is no page to turn.
         when Files.Input_Actions.No_Grid_Move
            | Files.Input_Actions.Grid_Page_Up
            | Files.Input_Actions.Grid_Page_Down =>
            null;
      end case;
      return Changed_Result (Old_Index, Files.Model.Root_Selector.Selected_Index (Model), Controller_Selection_Moved);
   end Root_Highlight_Result;

   function Selection_Result
     (Model      : in out Files.Model.Window_Model;
      Navigation : Files.Input_Actions.Grid_Navigation)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
   begin
      case Navigation.Move is
         when Files.Input_Actions.Grid_Step =>
            Files.Model.Selection.Move (Model, Navigation.Direction);
         when Files.Input_Actions.Grid_First =>
            Files.Model.Selection.Select_First_Visible (Model);
         when Files.Input_Actions.Grid_Last =>
            Files.Model.Selection.Select_Last_Visible (Model);
         when Files.Input_Actions.Grid_Page_Up | Files.Input_Actions.Grid_Page_Down =>
            Files.Model.Selection.Move_By_Page
              (Model, Files.Model.Selection.Page_Rows (Model),
               Down => Navigation.Move = Files.Input_Actions.Grid_Page_Down);
         when Files.Input_Actions.No_Grid_Move =>
            null;
      end case;
      return Changed_Result (Old_Index, Files.Model.Selection.Selected_Index (Model), Controller_Selection_Moved);
   end Selection_Result;

   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Action    : Files.Input_Actions.Input_Action;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result
 is separate;

end Files.Controller;
