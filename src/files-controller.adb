with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Guikit.Layout;

with Files.Applications;
with Files.Breadcrumbs;
with Files.Command_Palette;
with Files.Folder_Tree;
with Files.Settings_Form;
with Files.UTF8;

package body Files.Controller is
   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Root_Kind;
   use type Files.Model.Palette_Mode;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.String_Vectors.Vector;

   function Empty_Operation return Files.Operations.Operation_Result is
   begin
      return
        (Status    => Files.Operations.Operation_Disabled,
         Error_Key => Null_Unbounded_String,
         Path      => Null_Unbounded_String,
         Action    => Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
         others    => <>);
   end Empty_Operation;

   --  Seed the folder tree's root nodes from the available filesystem roots and
   --  the user's favorites, but only when it has not already been seeded. Used
   --  by the tree toggle command and the Copy to.../Move to... destination
   --  picker so both open onto the same populated tree.
   procedure Seed_Tree_If_Needed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      if not Files.Model.Tree_Is_Seeded (Model) then
         declare
            Roots : Files.File_System.Root_Entry_Vectors.Vector :=
              Files.File_System.Available_Root_Entries;
            Seeds : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
         begin
            for Path of Settings.Favorite_Paths loop
               Roots.Append
                 (Files.File_System.Root_Entry'
                    (Path        => Path,
                     Label       => Path,
                     Kind        => Files.File_System.Root_Favorite,
                     Volume_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
                     Ready       => Files.File_System.Root_Ready,
                     Removable   => False));
            end loop;
            for Root of Roots loop
               Seeds.Append
                 (Files.Folder_Tree.Entry_Seed'
                    (Path => Root.Path,
                     Name =>
                       (if Length (Root.Label) > 0
                        then Root.Label
                        else Root.Path)));
            end loop;
            Files.Model.Seed_Tree (Model, Seeds);
         end;
      end if;
   end Seed_Tree_If_Needed;

   function Make_Result
     (Status    : Controller_Status;
      Command   : Files.Commands.Command_Id := Files.Commands.No_Command;
      Operation : Files.Operations.Operation_Result := Empty_Operation)
      return Controller_Result is
   begin
      return
        (Status    => Status,
         Command   => Command,
         Operation => Operation);
   end Make_Result;

   function Successful_Command_Result
     (Command : Files.Commands.Command_Id)
      return Controller_Result
   is
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      Operation.Status := Files.Operations.Operation_Success;
      return Make_Result (Controller_Command_Executed, Command, Operation);
   end Successful_Command_Result;

   function Settings_Closed_Result
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model;
      Path  : String := "")
      return Controller_Result
   is
      Error_Key : constant String := "error.settings.closed";
   begin
      Files.Model.Set_Error (Model, Error_Key);
      return
        Make_Result
          (Controller_Ignored,
           Id,
           (Status    => Files.Operations.Operation_Disabled,
            Error_Key => To_Unbounded_String (Error_Key),
            Path      => To_Unbounded_String (Path),
            Action    => Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            others    => <>));
   end Settings_Closed_Result;

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
      Files.Model.Palette_Move_Selection (Model, Lines);
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
            Files.Model.Set_Rename_Text (Model, Text);
         when Files.Types.Focus_Command_Palette =>
            Files.Model.Palette_Set_Query (Model, Text);
         when Files.Types.Focus_Settings_Input =>
            Files.Model.Settings_Set_Focused_Value (Model, Text);
            declare
               Saved : constant Boolean :=
                 Files.Settings_Form.Apply (Model, Files.Model.Settings_Take_Change (Model));
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

   function Focused_Text
     (Model : Files.Model.Window_Model)
      return String is
   begin
      case Files.Model.Focus (Model) is
         when Files.Types.Focus_Path_Input =>
            return Files.Model.Path_Input_Text (Model);
         when Files.Types.Focus_Filter_Input =>
            return Files.Model.Filter_Text (Model);
         when Files.Types.Focus_Rename_Input =>
            return Files.Model.Rename_Text (Model);
         when Files.Types.Focus_Command_Palette =>
            return Files.Model.Palette_Query (Model);
         when Files.Types.Focus_Settings_Input =>
            return Files.Model.Settings_Focused_Value (Model);
         when Files.Types.Focus_Ownership_Input =>
            return Files.Model.Ownership_Input_Text (Model);
         when Files.Types.Focus_None =>
            return "";
      end case;
   end Focused_Text;

   function Append_Focused_Text
     (Model : in out Files.Model.Window_Model;
      Text  : String)
      return Controller_Result
 is separate;

   function Previous_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Previous_Boundary (Text, Cursor);
   end Previous_Text_Boundary;

   function Next_Text_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Next_Boundary (Text, Cursor);
   end Next_Text_Boundary;

   type Delete_Direction is (Delete_Backward, Delete_Forward);

   --  Shared body for the four Delete_Focused_Text_* variants, which are identical
   --  bar the direction and whether they delete to a word or a single character
   --  boundary. Defined below, after the word-boundary helpers it dispatches to.
   function Delete_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Direction : Delete_Direction;
      By_Word   : Boolean)
      return Controller_Result;

   function Delete_Focused_Text_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      return Delete_Focused_Text (Model, Delete_Backward, By_Word => False);
   end Delete_Focused_Text_Backward;

   function Delete_Focused_Text_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      return Delete_Focused_Text (Model, Delete_Forward, By_Word => False);
   end Delete_Focused_Text_Forward;

   function Previous_Word_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Previous_Word_Boundary (Text, Cursor);
   end Previous_Word_Boundary;

   function Next_Word_Boundary
     (Text   : String;
      Cursor : Natural)
      return Natural is
   begin
      return Files.UTF8.Next_Word_Boundary (Text, Cursor);
   end Next_Word_Boundary;

   function Delete_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Direction : Delete_Direction;
      By_Word   : Boolean)
      return Controller_Result
 is separate;

   function Delete_Focused_Text_Word_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      return Delete_Focused_Text (Model, Delete_Backward, By_Word => True);
   end Delete_Focused_Text_Word_Backward;

   function Delete_Focused_Text_Word_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      return Delete_Focused_Text (Model, Delete_Forward, By_Word => True);
   end Delete_Focused_Text_Word_Forward;

   --  Forward declaration: the reveal helper is defined alongside the other
   --  navigation helpers below, but Execute_Command routes to it above them.
   function Reveal_Selected_Item
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result;

   function Execute_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result
 is separate;

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

   function Toggle_Hidden_Files
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Updated   : Files.Settings.Settings_Model := Settings;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      Updated.Show_Hidden_Files := not Updated.Show_Hidden_Files;

      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Updated));
      if not Saved.Success then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Toggle_Hidden_Files_Command, Operation);
      end if;

      Settings := Updated;
      Operation := Files.Operations.Refresh (Model, Settings);
      if Operation.Status = Files.Operations.Operation_Failed then
         return Make_Result (Controller_Command_Executed, Files.Commands.Toggle_Hidden_Files_Command, Operation);
      end if;

      Files.Model.Set_Error (Model, "");
      Operation.Status := Files.Operations.Operation_Success;
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Null_Unbounded_String;

      return Make_Result (Controller_Command_Executed, Files.Commands.Toggle_Hidden_Files_Command, Operation);
   end Toggle_Hidden_Files;

   function Toggle_Show_Extensions
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Updated   : Files.Settings.Settings_Model := Settings;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      Updated.Show_File_Extensions := not Updated.Show_File_Extensions;

      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Updated));
      if not Saved.Success then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Toggle_Show_Extensions_Command, Operation);
      end if;

      --  Display-only setting: the item list is unchanged, so there is no
      --  directory reload. The next Build_Snapshot carries the new flag, which
      --  differs from the cached snapshot and rebuilds the frame on its own.
      Settings := Updated;
      Files.Model.Set_Error (Model, "");
      Operation.Status := Files.Operations.Operation_Success;
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Null_Unbounded_String;

      return Make_Result (Controller_Command_Executed, Files.Commands.Toggle_Show_Extensions_Command, Operation);
   end Toggle_Show_Extensions;

   function Toggle_Free_Space_Display
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
 is separate;

   function Handle_Command_Click
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result is
   begin
      if Id = Files.Commands.No_Command then
         return Make_Result (Controller_Ignored);
      end if;

      return Execute_Command (Id, Model, Settings, Modifiers);
   end Handle_Command_Click;

   function Handle_Search_Scope_Toggle
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result
 is separate;

   function Select_Root
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Root_Path : String)
      return Controller_Result
   is
      Operation : constant Files.Operations.Operation_Result :=
        Files.Operations.Select_Root (Model, Settings, Root_Path);
   begin
      return Make_Result (Controller_Command_Executed, Files.Commands.Select_Drive_Command, Operation);
   end Select_Root;

   --  Classify a favorite path as a live folder, a live file, or a stale entry
   --  whose target no longer exists. Any lookup failure is treated as stale so a
   --  broken favorite click degrades to a no-op rather than raising.
   type Favorite_Target is (Favorite_Folder, Favorite_File, Favorite_Stale);

   function Classify_Favorite (Path : String) return Favorite_Target is
      use type Ada.Directories.File_Kind;
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return Favorite_Stale;
      elsif Ada.Directories.Kind (Path) = Ada.Directories.Directory then
         return Favorite_Folder;
      else
         return Favorite_File;
      end if;
   exception
      when others =>
         return Favorite_Stale;
   end Classify_Favorite;

   --  Open a favorite that points at a file: navigate to its parent directory
   --  and select the file there, so the folder opens with the item highlighted.
   function Open_File_Favorite
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Controller_Result
   is
      Parent : constant String := Files.File_System.Parent_Directory (Path);
   begin
      if Parent = "" then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Operation : constant Files.Operations.Operation_Result :=
           Files.Operations.Select_Root (Model, Settings, Parent);
      begin
         if Operation.Status = Files.Operations.Operation_Navigated then
            declare
               Selected : constant Boolean :=
                 Files.Model.Select_By_Name (Model, Ada.Directories.Simple_Name (Path));
               pragma Unreferenced (Selected);
            begin
               null;
            end;
         end if;
         return Make_Result (Controller_Command_Executed, Files.Commands.Open_Selected_Root_Command, Operation);
      end;
   end Open_File_Favorite;

   --  Reveal the single selected item by navigating to its parent directory and
   --  selecting it there, mirroring the file-favorite click behaviour. When the
   --  parent is empty or already the current directory the reveal is a safe
   --  no-op that reports success without navigating.
   function Reveal_Selected_Item
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Controller_Result
   is
      Items : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
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

         declare
            Operation : constant Files.Operations.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Parent);
         begin
            if Operation.Status = Files.Operations.Operation_Navigated then
               declare
                  Selected : constant Boolean :=
                    Files.Model.Select_By_Name (Model, Ada.Directories.Simple_Name (Path));
                  pragma Unreferenced (Selected);
               begin
                  null;
               end;
            end if;
            return Make_Result
              (Controller_Command_Executed, Files.Commands.Open_Containing_Folder_Command, Operation);
         end;
      end;
   end Reveal_Selected_Item;

   function Handle_Root_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Root_Index : Natural)
      return Controller_Result is
   begin
      if not Files.Model.Root_Selector_Is_Open (Model)
        or else Root_Index = 0
        or else Root_Index > Files.Model.Root_Count (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;

      Files.Model.Set_Root_Selected_Index (Model, Root_Index);
      declare
         Path : constant String := Files.Model.Root_Path (Model, Positive (Root_Index));
         Kind : constant Files.File_System.Root_Kind :=
           Files.Model.Root_Kind (Model, Positive (Root_Index));
      begin
         --  A favorite may target a file or a stale path; ordinary roots are
         --  always directories and take the direct navigation path.
         if Kind = Files.File_System.Root_Favorite then
            case Classify_Favorite (Path) is
               when Favorite_Stale =>
                  --  Broken favorite: skip the click without raising so a stale
                  --  entry can never crash the selector.
                  return Make_Result (Controller_Ignored);
               when Favorite_File =>
                  return Open_File_Favorite (Model, Settings, Path);
               when Favorite_Folder =>
                  null;
            end case;
         end if;

         declare
            Operation : constant Files.Operations.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Path);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.Open_Selected_Root_Command, Operation);
         end;
      end;
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
      if Segment_Index = 0 or else Segment_Index > Natural (Segments.Length) then
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
            Operation : constant Files.Operations.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Target);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
         end;
      end;
   end Handle_Breadcrumb_Click;

   --  Load a tree node's direct subdirectories and attach them, honouring the
   --  hidden-files setting through Load_Directory. Failures and empty
   --  directories still mark the node loaded so it is not probed again.
   procedure Load_Tree_Children
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Positive;
      Node_Path  : String)
   is
      Load     : constant Files.File_System.Directory_Load_Result :=
        Files.File_System.Load_Directory (Node_Path, Settings);
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
   begin
      if Load.Success then
         for Item of Load.Items loop
            if Item.Kind = Files.Types.Directory_Item then
               Children.Append
                 (Files.Folder_Tree.Entry_Seed'
                    (Path => Item.Full_Path,
                     Name => Item.Name));
            end if;
         end loop;
      end if;
      Files.Model.Tree_Set_Children (Model, Node_Index, Children);
   end Load_Tree_Children;

   function Handle_Tree_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Node_Index : Natural;
      Toggle     : Boolean)
      return Controller_Result is separate;

   --  Launch the chosen "Open With" application on the stored target paths, then
   --  close the palette. The detached spawn status is advisory only (the wrapper
   --  shell, not the real handler), mirroring Open_Selected's detached-launch
   --  policy.
   function Launch_Application_Result
     (Model : in out Files.Model.Window_Model;
      App   : Files.Applications.Application)
      return Controller_Result
   is
      Action : constant Files.Settings.Open_Action :=
        Files.Applications.Build_Open_Action (App, Files.Model.Open_With_Targets (Model));
      Operation   : Files.Operations.Operation_Result := Empty_Operation;
      Exit_Status : Integer := 0;
      Spawned     : constant Boolean :=
        Files.Operations.Execute_Open_Action (Action, Exit_Status, Detach => True);
      pragma Unreferenced (Spawned);
   begin
      Files.Model.Close_Command_Palette (Model);
      Operation.Status := Files.Operations.Operation_Action_Executed;
      Operation.Action := Action;
      return Make_Result (Controller_Command_Executed, Files.Commands.Open_With_Command, Operation);
   end Launch_Application_Result;

   --  Act on the palette's highlighted command (from Palette_Selected_Id):
   --  launch the application in Open-With mode, otherwise execute the command,
   --  closing the palette on success (except Open_With, which re-opens the
   --  palette in application-picker mode).
   function Activate_Palette_Command
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result
   is
      Id : constant Natural := Files.Model.Palette_Selected_Id (Model);
   begin
      if Id = 0 then
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Mode_Of (Model) = Files.Model.Palette_Open_With then
         declare
            Apps : constant Files.Applications.Application_Vectors.Vector :=
              Files.Applications.Available_Applications;
         begin
            if Id in 1 .. Natural (Apps.Length) then
               return Launch_Application_Result (Model, Apps.Element (Id));
            end if;
            return Make_Result (Controller_Ignored);
         end;
      end if;

      declare
         Command : constant Files.Commands.Command_Id := Files.Commands.Command_Id'Val (Id);
         Result  : constant Controller_Result := Execute_Command (Command, Model, Settings, Modifiers);
      begin
         if Result.Status /= Controller_Ignored
           and then Command /= Files.Commands.Open_With_Command
         then
            Files.Model.Close_Command_Palette (Model);
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
      Operation : constant Files.Operations.Operation_Result :=
        Files.Operations.Begin_Paste
          (Model, Settings, Source_Paths, Mode, From_Clipboard => False);
   begin
      return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
   end Handle_Drop_Import;

   function Scroll_Info_Result
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result
   is
      Old_Lines : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
   begin
      Files.Model.Scroll_Info_Pane (Model, Lines);
      return
        Make_Result
          (if Files.Model.Info_Pane_Scroll_Lines (Model) = Old_Lines
           then Controller_Ignored
           else Controller_Command_Executed);
   end Scroll_Info_Result;

   function Scroll_Settings_Result
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result is
   begin
      Files.Model.Settings_Scroll (Model, Lines);
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
      return
        Make_Result
          (if Files.Model.Main_View_Scroll_Lines (Model) = Old_Lines
           then Controller_Ignored
           else Controller_Command_Executed);
   end Scroll_Main_Result;

   function Handle_Scroll
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
      return Controller_Result is
   begin
      if Lines = 0 then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Root_Selector_Is_Open (Model)
        and then not Files.Model.Command_Palette_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Command_Palette_Is_Open (Model) then
         if Files.Model.Palette_Result_Count (Model) = 0 then
            return Make_Result (Controller_Ignored);
         else
            Scroll_Palette_Selection (Model, Lines);
            return Make_Result (Controller_Palette_Updated);
         end if;
      elsif Files.Model.Settings_Pane_Is_Open (Model) then
         return Scroll_Settings_Result (Model, Lines);
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
   --  a toggle/choice/number or an add/remove auto-saves (persist + refresh);
   --  text edits are applied but saved on commit.
   function Applied_Settings_Change
     (Model : in out Files.Model.Window_Model)
      return Controller_Result is
   begin
      if Files.Settings_Form.Apply (Model, Files.Model.Settings_Take_Change (Model)) then
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command);
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
      Count  : constant Natural := Files.Model.Settings_Section_Count (Model);
      Active : constant Natural := Files.Model.Settings_Active_Section (Model);
   begin
      if Count <= 1 then
         return;
      elsif Forward then
         Files.Model.Settings_Set_Active_Section (Model, (if Active >= Count then 1 else Active + 1));
      else
         Files.Model.Settings_Set_Active_Section (Model, (if Active <= 1 then Count else Active - 1));
      end if;
   end Cycle_Settings_Section;

   function Handle_Settings_Click
     (Model : in out Files.Model.Window_Model;
      X     : Integer;
      Y     : Integer)
      return Controller_Result is
   begin
      if Files.Model.Command_Palette_Is_Open (Model)
        or else not Files.Model.Settings_Pane_Is_Open (Model)
        or else not Files.Model.Settings_Click (Model, X, Y)
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
      Old_Index : constant Natural := Files.Model.Root_Selected_Index (Model);
   begin
      Files.Model.Move_Root_Selection (Model, Direction);
      return
        Make_Result
          (if Files.Model.Root_Selected_Index (Model) = Old_Index
           then Controller_Ignored
           else Controller_Selection_Moved);
   end Root_Selection_Result;

   function Root_Jump_Result
     (Model : in out Files.Model.Window_Model;
      Index : Natural)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Root_Selected_Index (Model);
   begin
      Files.Model.Set_Root_Selected_Index (Model, Index);
      return
        Make_Result
          (if Files.Model.Root_Selected_Index (Model) = Old_Index
           then Controller_Ignored
           else Controller_Selection_Moved);
   end Root_Jump_Result;

   --  Grid selection paging uses a fixed page size: the exact viewport row
   --  count is a GLFW/render concern the pure controller cannot see, so a
   --  sensible constant page is used (matching the +/-10 keyboard scroll step).
   Grid_Page_Rows : constant := 10;

   function First_Selection_Result
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selected_Index (Model);
   begin
      Files.Model.Select_First_Visible (Model);
      return
        Make_Result
          (if Files.Model.Selected_Index (Model) = Old_Index
           then Controller_Ignored
           else Controller_Selection_Moved);
   end First_Selection_Result;

   function Last_Selection_Result
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selected_Index (Model);
   begin
      Files.Model.Select_Last_Visible (Model);
      return
        Make_Result
          (if Files.Model.Selected_Index (Model) = Old_Index
           then Controller_Ignored
           else Controller_Selection_Moved);
   end Last_Selection_Result;

   function Page_Selection_Result
     (Model : in out Files.Model.Window_Model;
      Down  : Boolean)
      return Controller_Result
   is
      Old_Index : constant Natural := Files.Model.Selected_Index (Model);
   begin
      Files.Model.Move_Selection_By_Page (Model, Grid_Page_Rows, Down);
      return
        Make_Result
          (if Files.Model.Selected_Index (Model) = Old_Index
           then Controller_Ignored
           else Controller_Selection_Moved);
   end Page_Selection_Result;

   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Controller_Result
 is separate;

end Files.Controller;
