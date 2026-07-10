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
   is
      function Disabled_Operation (Error_Key : String) return Files.Operations.Operation_Result is
      begin
         Files.Model.Set_Error (Model, Error_Key);
         return
           (Status    => Files.Operations.Operation_Disabled,
            Error_Key => To_Unbounded_String (Error_Key),
            Path      => Null_Unbounded_String,
            Action    => Files.Settings.Make_Action ("", Files.Settings.String_Vectors.Empty_Vector),
            others    => <>);
      end Disabled_Operation;
   begin
      case Id is
         when Files.Commands.Navigate_Back_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.history.back_unavailable"));
         when Files.Commands.Navigate_Forward_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.history.forward_unavailable"));
         when Files.Commands.Open_Selected_Items_Command
            | Files.Commands.Delete_Selected_Items_Command
            | Files.Commands.Toggle_Info_Pane_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.selection.empty"));
         when Files.Commands.Rename_Selected_Items_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.rename.disabled"));
         when Files.Commands.Create_File_Command | Files.Commands.New_Folder_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.create.pending"));
         when Files.Commands.Clear_Filter_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.filter.empty"));
         when Files.Commands.Open_Selected_Root_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.root.selection.empty"));
         when Files.Commands.Eject_Selected_Root_Command =>
            return
              Make_Result
                (Controller_Ignored, Id, Disabled_Operation ("error.root.eject_unavailable"));
         when Files.Commands.Save_Settings_Command | Files.Commands.Reset_Settings_Command =>
            return Settings_Closed_Result (Id, Model);
         when others =>
            return Make_Result (Controller_Ignored, Id);
      end case;
   end Disabled_Command_Result;

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
   is
      Old_Text : constant String := Focused_Text (Model);
      Cursor   : constant Natural := Files.Model.Text_Cursor_Position (Model);
      New_Text : Unbounded_String;
   begin
      if Text = "" then
         return Make_Result (Controller_Ignored);
      end if;

      --  With no text field focused the file grid owns the keyboard: bare
      --  printable characters drive type-to-select instead of editing a field.
      --  Modifier combinations (Ctrl/Alt shortcuts) never reach here because the
      --  GLFW character callback only emits printable text, so shortcuts stay on
      --  the command path.
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         declare
            Matched : Boolean;
         begin
            Files.Model.Type_Ahead_Input (Model, Text, Matched);
            return Make_Result (if Matched then Controller_Selection_Moved else Controller_Ignored);
         end;
      end if;

      --  Rename edits broadcast to every synchronized caret rather than the
      --  single focused buffer.
      if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename_Insert_At_Carets (Model, Text)
              then Controller_Text_Updated
              else Controller_Ignored);
      end if;

      if Cursor = 0 then
         New_Text := To_Unbounded_String (Text & Old_Text);
      elsif Cursor >= Old_Text'Length then
         New_Text := To_Unbounded_String (Old_Text & Text);
      else
         New_Text :=
           To_Unbounded_String
             (Old_Text (Old_Text'First .. Old_Text'First + Cursor - 1)
              & Text
              & Old_Text (Old_Text'First + Cursor .. Old_Text'Last));
      end if;

      Replace_Focused_Text (Model, To_String (New_Text));
      Files.Model.Set_Text_Cursor_Position (Model, Cursor + Text'Length);
      return Make_Result (Controller_Text_Updated);
   end Append_Focused_Text;

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

   function Remove_Text_Range
     (Text  : String;
      First : Natural;
      Last  : Natural)
      return String
   is
      Start_Index : constant Natural := Natural'Min (First, Text'Length);
      End_Index   : constant Natural := Natural'Min (Last, Text'Length);
      Result      : Unbounded_String;
   begin
      if Text = "" or else Start_Index >= End_Index then
         return Text;
      end if;

      if Start_Index > 0 then
         Append (Result, Text (Text'First .. Text'First + Start_Index - 1));
      end if;

      if End_Index < Text'Length then
         Append (Result, Text (Text'First + End_Index .. Text'Last));
      end if;

      return To_String (Result);
   end Remove_Text_Range;

   function Delete_Focused_Text_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Text : constant String := Focused_Text (Model);
      Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
      Previous : Natural;
   begin
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename_Delete_Backward (Model)
              then Controller_Text_Updated
              else Controller_Ignored);
      elsif Text'Length = 0 or else Cursor = 0 then
         return Make_Result (Controller_Ignored);
      end if;

      Previous := Previous_Text_Boundary (Text, Cursor);
      Replace_Focused_Text (Model, Remove_Text_Range (Text, Previous, Cursor));
      Files.Model.Set_Text_Cursor_Position (Model, Previous);
      return Make_Result (Controller_Text_Updated);
   end Delete_Focused_Text_Backward;

   function Delete_Focused_Text_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Text   : constant String := Focused_Text (Model);
      Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
      Next   : Natural;
   begin
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename_Delete_Forward (Model)
              then Controller_Text_Updated
              else Controller_Ignored);
      elsif Text'Length = 0 or else Cursor >= Text'Length then
         return Make_Result (Controller_Ignored);
      end if;

      Next := Next_Text_Boundary (Text, Cursor);
      Replace_Focused_Text (Model, Remove_Text_Range (Text, Cursor, Next));
      Files.Model.Set_Text_Cursor_Position (Model, Cursor);
      return Make_Result (Controller_Text_Updated);
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

   function Delete_Focused_Text_Word_Backward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Text   : constant String := Focused_Text (Model);
      Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
      Boundary : constant Natural := Previous_Word_Boundary (Text, Cursor);
   begin
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename_Delete_Word_Backward (Model)
              then Controller_Text_Updated
              else Controller_Ignored);
      elsif Cursor = 0 then
         return Make_Result (Controller_Ignored);
      end if;

      Replace_Focused_Text (Model, Remove_Text_Range (Text, Boundary, Cursor));
      Files.Model.Set_Text_Cursor_Position (Model, Boundary);
      return Make_Result (Controller_Text_Updated);
   end Delete_Focused_Text_Word_Backward;

   function Delete_Focused_Text_Word_Forward
     (Model : in out Files.Model.Window_Model)
      return Controller_Result
   is
      Text     : constant String := Focused_Text (Model);
      Cursor   : constant Natural := Files.Model.Text_Cursor_Position (Model);
      Boundary : constant Natural := Next_Word_Boundary (Text, Cursor);
   begin
      if Files.Model.Focus (Model) = Files.Types.Focus_None then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
         return
           Make_Result
             (if Files.Model.Rename_Delete_Word_Forward (Model)
              then Controller_Text_Updated
              else Controller_Ignored);
      elsif Cursor >= Text'Length then
         return Make_Result (Controller_Ignored);
      end if;

      Replace_Focused_Text (Model, Remove_Text_Range (Text, Cursor, Boundary));
      Files.Model.Set_Text_Cursor_Position (Model, Cursor);
      return Make_Result (Controller_Text_Updated);
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
   is
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      if Files.Model.Root_Selector_Is_Open (Model)
        and then not Files.Commands.Allowed_With_Root_Selector (Id)
      then
         return Make_Result (Controller_Ignored, Id);
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then not Files.Commands.Allowed_With_Settings_Pane (Id)
      then
         return Make_Result (Controller_Ignored, Id);
      elsif not Files.Commands.Is_Enabled (Id, Model) then
         return Disabled_Command_Result (Id, Model);
      end if;

      case Id is
         when Files.Commands.Navigate_Home_Command =>
            Operation := Files.Operations.Navigate_Home (Model, Settings);
         when Files.Commands.Navigate_Parent_Command =>
            Operation := Files.Operations.Navigate_Parent (Model, Settings);
         when Files.Commands.Navigate_Trash_Command =>
            Operation := Files.Operations.Navigate_Trash (Model, Settings);
         when Files.Commands.Navigate_Recent_Command =>
            Operation := Files.Operations.Navigate_Recent (Model, Settings);
         when Files.Commands.Restore_From_Trash_Command =>
            Operation := Files.Operations.Restore_Selected_From_Trash (Model, Settings);
         when Files.Commands.Empty_Trash_Command =>
            Operation := Files.Operations.Empty_Trash (Model, Settings);
         when Files.Commands.Undo_Command =>
            Operation := Files.Operations.Undo_Last (Model, Settings);
         when Files.Commands.Redo_Command =>
            Operation := Files.Operations.Redo_Last (Model, Settings);
         when Files.Commands.Navigate_Back_Command =>
            Operation := Files.Operations.Navigate_Back (Model, Settings);
         when Files.Commands.Navigate_Forward_Command =>
            Operation := Files.Operations.Navigate_Forward (Model, Settings);
         when Files.Commands.Open_Selected_Items_Command =>
            Operation := Files.Operations.Open_Selected (Model, Settings, Modifiers);
         when Files.Commands.Open_With_Command =>
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Targets : Files.Types.String_Vectors.Vector;
            begin
               for Item of Items loop
                  Targets.Append (Item.Full_Path);
               end loop;
               --  Open_Command_Palette resets palette mode and targets, so
               --  capture the selection into the model only afterwards.
               Files.Model.Open_Command_Palette (Model);
               Files.Model.Set_Open_With_Targets (Model, Targets);
               Files.Model.Set_Command_Palette_Mode (Model, Files.Model.Palette_Open_With);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Delete_Selected_Items_Command =>
            Operation := Files.Operations.Delete_Selected (Model, Settings);
         when Files.Commands.Delete_Selected_Permanently_Command =>
            Operation := Files.Operations.Delete_Selected_Permanently (Model, Settings);
         when Files.Commands.Copy_Selected_Items_Command =>
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Paths : Files.Types.String_Vectors.Vector;
            begin
               for Item of Items loop
                  Paths.Append (Item.Full_Path);
               end loop;
               Files.Model.Set_Clipboard
                 (Model, Paths, Files.Model.Clipboard_Copy);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Cut_Selected_Items_Command =>
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Paths : Files.Types.String_Vectors.Vector;
            begin
               for Item of Items loop
                  Paths.Append (Item.Full_Path);
               end loop;
               Files.Model.Set_Clipboard
                 (Model, Paths, Files.Model.Clipboard_Cut);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Duplicate_Selected_Command =>
            Operation := Files.Operations.Duplicate_Selected (Model, Settings);
         when Files.Commands.Create_Symlink_Command =>
            Operation := Files.Operations.Create_Symlink_Selected (Model, Settings);
         when Files.Commands.Create_Hardlink_Command =>
            Operation := Files.Operations.Create_Hardlink_Selected (Model, Settings);
         when Files.Commands.Open_Terminal_Command =>
            Operation := Files.Operations.Open_Terminal (Model, Settings);
         when Files.Commands.Compress_Zip_Command =>
            Operation :=
              Files.Operations.Compress_Selected
                (Model, Settings, Files.Operations.Zip_Archive);
         when Files.Commands.Compress_7z_Command =>
            Operation :=
              Files.Operations.Compress_Selected
                (Model, Settings, Files.Operations.Seven_Zip_Archive);
         when Files.Commands.Extract_Archive_Command =>
            Operation := Files.Operations.Extract_Selected (Model, Settings);
         when Files.Commands.Paste_Items_Command =>
            declare
               use type Files.Model.Clipboard_Mode;
               Paths : constant Files.Types.String_Vectors.Vector :=
                 Files.Model.Clipboard_Paths (Model);
               Mode  : constant Files.Model.Clipboard_Mode :=
                 Files.Model.Clipboard_Mode_Of (Model);
               Drop_Mode : constant Files.File_System.Drop_Import_Mode :=
                 (if Mode = Files.Model.Clipboard_Cut
                  then Files.File_System.Drop_Move
                  else Files.File_System.Drop_Copy);
            begin
               --  Begin_Paste executes immediately when no destination name
               --  collides, or arms the conflict dialog when one does. The cut
               --  clipboard is cleared by the operation once the move actually
               --  runs (immediately, or after the last conflict is resolved).
               Operation :=
                 Files.Operations.Begin_Paste (Model, Settings, Paths, Drop_Mode);
            end;
         when Files.Commands.Generate_Thumbnails_Command =>
            Operation := Files.Operations.Generate_Selected_Thumbnails (Model, Settings);
         when Files.Commands.Search_Recursive_Command =>
            Operation := Files.Operations.Run_Recursive_Search (Model, Settings);
         when Files.Commands.Search_Contents_Command =>
            Operation := Files.Operations.Run_Content_Search (Model, Settings);
         when Files.Commands.Refresh_Directory_Command =>
            Operation := Files.Operations.Refresh (Model, Settings);
         when Files.Commands.Open_Containing_Folder_Command =>
            return Reveal_Selected_Item (Model, Settings);
         when Files.Commands.Open_Selected_Root_Command =>
            return Handle_Root_Click (Model, Settings, Files.Model.Root_Selected_Index (Model));
         when Files.Commands.Eject_Selected_Root_Command =>
            Operation := Files.Operations.Eject_Selected_Root (Model);
         when Files.Commands.Create_File_Command =>
            Files.Model.Begin_Create_File
              (Model,
               Files.File_System.Next_Untitled_Name (Files.Model.Current_Path (Model)));
            Files.Model.Set_Error (Model, "");
         when Files.Commands.New_Folder_Command =>
            Files.Model.Begin_Create_Folder
              (Model,
               Files.File_System.Next_Untitled_Name (Files.Model.Current_Path (Model)));
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Select_Drive_Command =>
            if Files.Model.Root_Selector_Is_Open (Model) then
               Files.Model.Close_Root_Selector (Model);
            else
               declare
                  Roots : Files.File_System.Root_Entry_Vectors.Vector :=
                    Files.File_System.Available_Root_Entries;
               begin
                  for Path of Settings.Favorite_Paths loop
                     Roots.Append
                       (Files.File_System.Root_Entry'
                          (Path        => Path,
                           --  Use the "root.favorite|<name>" label token so the
                           --  selector renders the star prefix and base name
                           --  rather than the full path.
                           Label       =>
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Files.File_System.Root_Label
                                  (Ada.Strings.Unbounded.To_String (Path),
                                   Files.File_System.Root_Favorite)),
                           Kind        => Files.File_System.Root_Favorite,
                           Volume_Name => Ada.Strings.Unbounded.Null_Unbounded_String,
                           Ready       => Files.File_System.Root_Ready,
                           Removable   => False));
                  end loop;
                  Files.Model.Open_Root_Selector (Model, Roots);
               end;
            end if;
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Toggle_Folder_Tree_Command =>
            if Files.Model.Tree_Panel_Is_Open (Model) then
               Files.Model.Close_Tree_Panel (Model);
            else
               Seed_Tree_If_Needed (Model, Settings);
               Files.Model.Open_Tree_Panel (Model);
            end if;
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Copy_To_Command | Files.Commands.Move_To_Command =>
            --  Capture the current selection, then open the folder tree as a
            --  destination picker seeded with the same roots the toggle uses.
            declare
               Items : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
               Paths : Files.Types.String_Vectors.Vector;
               Mode  : constant Files.Model.Tree_Pick_Mode :=
                 (if Id = Files.Commands.Move_To_Command
                  then Files.Model.Pick_Move
                  else Files.Model.Pick_Copy);
            begin
               for Item of Items loop
                  Paths.Append (Item.Full_Path);
               end loop;
               Files.Model.Begin_Tree_Pick
                 (Model, Mode, Paths, Files.Model.Current_Path (Model));
               Seed_Tree_If_Needed (Model, Settings);
               Files.Model.Open_Tree_Panel (Model);
               Files.Model.Set_Error (Model, "");
               Operation.Status := Files.Operations.Operation_Success;
            end;
         when Files.Commands.Toggle_Quick_Look_Command =>
            --  Toggle the Quick Look overlay. Opening reads the bounded preview
            --  bytes (or classifies the image) so the overlay shows text/image
            --  content rather than the metadata-only pure fallback.
            if Files.Model.Quick_Look_Is_Open (Model) then
               Files.Model.Close_Quick_Look (Model);
            else
               Files.Model.Open_Quick_Look
                 (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
            end if;
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operations.Operation_Success;
         when Files.Commands.Reset_Settings_Command =>
            Files.Model.Set_Settings_Draft (Model, Files.Settings.Reset_Draft_To_Defaults);
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operations.Operation_Success;
         when Files.Commands.Close_Command_Palette_Command =>
            if Files.Model.Label_Picker_Is_Open (Model) then
               Files.Model.Close_Label_Picker (Model);
            elsif Files.Model.Context_Menu_Is_Open (Model) then
               Files.Model.Close_Context_Menu (Model);
            elsif Files.Model.Command_Palette_Is_Open (Model) then
               Files.Model.Close_Command_Palette (Model);
            elsif Files.Model.Root_Selector_Is_Open (Model) then
               Files.Model.Close_Root_Selector (Model);
            elsif Files.Model.Sort_Menu_Is_Open (Model) then
               Files.Model.Close_Sort_Menu (Model);
            else
               Files.Model.Cancel_Focus_Or_Edit (Model);
            end if;
         when others =>
            if Id = Files.Commands.Toggle_Settings_Pane_Command
              and then not Files.Model.Settings_Pane_Is_Open (Model)
            then
               Files.Model.Begin_Settings_Edit (Model, Files.Settings.Make_Draft (Settings));
            else
               Files.Commands.Execute (Id, Model);
            end if;
            case Id is
               when Files.Commands.Focus_Path_Input_Command
                  | Files.Commands.Focus_Filter_Input_Command
                  | Files.Commands.Open_Command_Palette_Command =>
                  Files.Model.Set_Error (Model, "");
               when others =>
                  null;
            end case;
      end case;

      if Operation.Status = Files.Operations.Operation_Disabled
        and then Length (Operation.Error_Key) = 0
        and then not Files.Commands.Requires_Settings_Path (Id)
      then
         Operation.Status := Files.Operations.Operation_Success;
      end if;

      return Make_Result (Controller_Command_Executed, Id, Operation);
   end Execute_Command;

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
   is
      Applied : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Apply_Draft (Settings, Files.Model.Settings_Draft_Of (Model));
      Final     : Files.Settings.Settings_Model;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      if not Files.Model.Settings_Pane_Is_Open (Model) then
         return Settings_Closed_Result (Files.Commands.Save_Settings_Command, Model, Settings_Path);
      elsif not Applied.Success then
         declare
            Draft : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
         begin
            Draft.Valid := False;
            Draft.Error_Key := Applied.Error_Key;
            Files.Model.Set_Settings_Draft (Model, Draft);
         end;
         Files.Model.Set_Error (Model, To_String (Applied.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Applied.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      Final := Applied.Settings;
      Store_Shortcut_Overrides (Final);
      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Final));
      if not Saved.Success then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      Settings := Final;
      Operation := Files.Operations.Refresh (Model, Settings);
      if Operation.Status = Files.Operations.Operation_Failed then
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      Files.Model.Set_Error (Model, "");
      Files.Model.Set_Settings_Draft (Model, Files.Settings.Make_Draft (Settings));
      Operation.Status := Files.Operations.Operation_Success;
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Null_Unbounded_String;

      return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
   end Save_Settings;

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
   is
      Updated   : Files.Settings.Settings_Model := Settings;
      Saved     : Files.Settings.Settings_Write_Result;
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      Updated.Show_Used_Space := not Updated.Show_Used_Space;

      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Updated));
      if not Saved.Success then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result
           (Controller_Command_Executed, Files.Commands.Toggle_Free_Space_Display_Command, Operation);
      end if;

      --  Display-only setting: the item list is unchanged, so there is no
      --  directory reload. The next Build_Snapshot carries the new flag, which
      --  differs from the cached snapshot and rebuilds the frame on its own.
      Settings := Updated;
      Files.Model.Set_Error (Model, "");
      Operation.Status := Files.Operations.Operation_Success;
      Operation.Path := To_Unbounded_String (Settings_Path);
      Operation.Error_Key := Null_Unbounded_String;

      return Make_Result
        (Controller_Command_Executed, Files.Commands.Toggle_Free_Space_Display_Command, Operation);
   end Toggle_Free_Space_Display;

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
   is
      Next : constant Files.Types.Search_Scope :=
        Files.Types.Next_Scope (Files.Model.Search_Scope_Of (Model));
      Had_Results : constant Boolean := Files.Model.Search_Results_Are_Active (Model);
      Has_Query   : constant Boolean := Files.Model.Filter_Text (Model) /= "";
      Operation   : Files.Operations.Operation_Result;
   begin
      Files.Model.Set_Search_Scope (Model, Next);

      case Next is
         when Files.Types.Filter_Here =>
            --  Returning to live filtering: drop any recorded search results and
            --  reload the real directory so the plain listing comes back.
            Files.Model.Clear_Search_Results (Model);
            if Had_Results then
               Operation := Files.Operations.Refresh (Model, Settings);
               return Make_Result
                 (Controller_Command_Executed, Files.Commands.Clear_Filter_Command, Operation);
            end if;
            return Make_Result (Controller_Command_Executed, Files.Commands.Clear_Filter_Command);
         when Files.Types.Search_Names =>
            if Has_Query then
               Operation := Files.Operations.Run_Recursive_Search (Model, Settings);
            elsif Had_Results then
               Operation := Files.Operations.Refresh (Model, Settings);
               Files.Model.Clear_Search_Results (Model);
               Files.Model.Set_Search_Scope (Model, Next);
            end if;
            return Make_Result
              (Controller_Command_Executed, Files.Commands.Search_Recursive_Command, Operation);
         when Files.Types.Search_Contents =>
            if Has_Query then
               Operation := Files.Operations.Run_Content_Search (Model, Settings);
            elsif Had_Results then
               Operation := Files.Operations.Refresh (Model, Settings);
               Files.Model.Clear_Search_Results (Model);
               Files.Model.Set_Search_Scope (Model, Next);
            end if;
            return Make_Result
              (Controller_Command_Executed, Files.Commands.Search_Contents_Command, Operation);
      end case;
   end Handle_Search_Scope_Toggle;

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
      return Controller_Result is
   begin
      if not Files.Model.Tree_Panel_Is_Open (Model)
        or else Node_Index = 0
        or else Node_Index > Files.Model.Tree_Node_Count (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Index     : constant Positive := Positive (Node_Index);
         Node_Path : constant String := Files.Model.Tree_Node_Path (Model, Index);
      begin
         if Toggle then
            if not Files.Model.Tree_Node_Is_Expanded (Model, Index)
              and then not Files.Model.Tree_Node_Is_Loaded (Model, Index)
            then
               Load_Tree_Children (Model, Settings, Index, Node_Path);
            end if;
            Files.Model.Tree_Toggle_Expanded (Model, Index);
            return Make_Result
              (Controller_Command_Executed,
               Files.Commands.Toggle_Folder_Tree_Command,
               Empty_Operation);
         end if;

         --  While a Copy to.../Move to... picker is active a label click chooses
         --  the highlighted destination instead of navigating the main view.
         if Files.Model.Tree_Pick_Is_Active (Model) then
            Files.Model.Set_Tree_Pick_Target (Model, Node_Path);
            Files.Model.Set_Error (Model, "");
            return Make_Result
              (Controller_Command_Executed, Files.Commands.No_Command, Empty_Operation);
         end if;

         if not Files.Model.Tree_Node_Is_Loaded (Model, Index) then
            Load_Tree_Children (Model, Settings, Index, Node_Path);
         end if;
         Files.Model.Tree_Set_Expanded (Model, Index, True);

         declare
            Operation : constant Files.Operations.Operation_Result :=
              Files.Operations.Select_Root (Model, Settings, Node_Path);
         begin
            return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
         end;
      end;
   end Handle_Tree_Click;

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
      return Controller_Result is
   begin
      if Files.Model.Command_Palette_Is_Open (Model)
        or else Files.Model.Root_Selector_Is_Open (Model)
        or else Files.Model.Settings_Pane_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Visible_Index = 0 or else Visible_Index > Files.Model.Visible_Count (Model) then
         return Make_Result (Controller_Ignored);
      end if;

      Files.Model.Cancel_Focus_Or_Edit (Model);
      if Visible_Index > Files.Model.Visible_Count (Model) then
         --  The clicked row was the trailing temporary (create-file) row, which
         --  Cancel_Focus_Or_Edit just removed; report a successful state-only
         --  cancel rather than an unrelated (close-palette) command id.
         return Successful_Command_Result (Files.Commands.No_Command);
      end if;

      if Modifiers (Guikit.Input.Shift_Key) and then not Activate then
         declare
            Anchor : constant Natural := Files.Model.Selected_Index (Model);
         begin
            Files.Model.Select_Visible_Range
              (Model,
               Positive ((if Anchor = 0 then Visible_Index else Anchor)),
               Positive (Visible_Index));
         end;
      elsif Modifiers (Guikit.Input.Control_Key) and then not Activate then
         Files.Model.Toggle_Visible_Selection (Model, Positive (Visible_Index));
      else
         Files.Model.Select_Visible (Model, Positive (Visible_Index));
      end if;

      if Activate then
         return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
      end if;

      return Make_Result (Controller_Selection_Moved);
   end Handle_Item_Click;

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
      return Controller_Result is
   begin
      if Lines = 0 then
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Is_Open (Model)
        and then Target /= Files.Events.Scroll_Auto
        and then Target /= Files.Events.Scroll_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Root_Selector_Is_Open (Model)
        and then not Files.Model.Command_Palette_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then not Files.Model.Command_Palette_Is_Open (Model)
        and then Target /= Files.Events.Scroll_Auto
        and then Target /= Files.Events.Scroll_Settings_Pane
      then
         return Make_Result (Controller_Ignored);
      end if;

      case Target is
         when Files.Events.Scroll_Auto =>
            return Handle_Scroll (Model, Lines);
         when Files.Events.Scroll_Command_Palette =>
            if Files.Model.Command_Palette_Is_Open (Model) then
               if Files.Model.Palette_Result_Count (Model) = 0 then
                  return Make_Result (Controller_Ignored);
               else
                  Scroll_Palette_Selection (Model, Lines);
                  return Make_Result (Controller_Palette_Updated);
               end if;
            end if;
         when Files.Events.Scroll_Info_Pane =>
            if Files.Model.Info_Pane_Is_Open (Model) then
               return Scroll_Info_Result (Model, Lines);
            end if;
         when Files.Events.Scroll_Settings_Pane =>
            if Files.Model.Settings_Pane_Is_Open (Model) then
               return Scroll_Settings_Result (Model, Lines);
            end if;
         when Files.Events.Scroll_Main_View =>
            return Scroll_Main_Result (Model, Lines);
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Targeted_Scroll;

   function Handle_Text_Click
     (Model           : in out Files.Model.Window_Model;
      Target          : Files.Types.Focus_Target;
      Cursor_Position : Natural;
      Item_Index      : Natural := 0)
      return Controller_Result
   is
      Old_Focus  : constant Files.Types.Focus_Target := Files.Model.Focus (Model);
      Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
   begin
      if Target = Files.Types.Focus_Command_Palette
        and then not Files.Model.Command_Palette_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Target = Files.Types.Focus_Settings_Input
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         return Make_Result (Controller_Ignored);
      elsif Target = Files.Types.Focus_Rename_Input
        and then not Files.Model.Rename_Is_Active (Model)
      then
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Is_Open (Model)
        and then Target /= Files.Types.Focus_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Root_Selector_Is_Open (Model)
        and then Target /= Files.Types.Focus_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      elsif Files.Model.Settings_Pane_Is_Open (Model)
        and then Target /= Files.Types.Focus_Settings_Input
        and then Target /= Files.Types.Focus_Command_Palette
      then
         return Make_Result (Controller_Ignored);
      end if;

      case Target is
         when Files.Types.Focus_Path_Input =>
            if Files.Model.Focus (Model) /= Files.Types.Focus_Path_Input then
               Files.Model.Focus_Path_Input (Model);
            end if;
         when Files.Types.Focus_Filter_Input =>
            if Files.Model.Focus (Model) /= Files.Types.Focus_Filter_Input then
               Files.Model.Focus_Filter_Input (Model);
            end if;
         when Files.Types.Focus_Rename_Input =>
            Files.Model.Focus_Rename_Input (Model);
         when Files.Types.Focus_Command_Palette =>
            Files.Model.Focus_Command_Palette_Input (Model);
         when Files.Types.Focus_Settings_Input =>
            --  Settings clicks route through Handle_Settings_Click (the panel
            --  hit-tests them), not the generic text-click path.
            null;
         when Files.Types.Focus_Ownership_Input =>
            --  The ownership editor is opened through its own click action, not
            --  the generic text-click path.
            return Make_Result (Controller_Ignored);
         when Files.Types.Focus_None =>
            return Make_Result (Controller_Ignored);
      end case;

      --  A rename click moves only the clicked field's caret, keeping the
      --  other synchronized carets in place.
      if Target = Files.Types.Focus_Rename_Input then
         Files.Model.Set_Rename_Caret (Model, Item_Index, Cursor_Position);
         return Make_Result (Controller_Text_Updated);
      end if;

      Files.Model.Set_Text_Cursor_Position (Model, Cursor_Position);
      return
        Make_Result
          (if Files.Model.Focus (Model) = Old_Focus
             and then Files.Model.Text_Cursor_Position (Model) = Old_Cursor
           then Controller_Ignored
           else Controller_Text_Updated);
   end Handle_Text_Click;

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
      return Controller_Result is
   begin
      if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         Files.Model.Settings_Cancel_Capture (Model);
         return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
      elsif Key = Guikit.Input.Key_Backspace and then Modifiers = Guikit.Input.No_Modifiers then
         --  Backspace clears the binding (unbind).
         Files.Model.Settings_Set_Captured_Shortcut (Model, "");
         return Applied_Settings_Change (Model);
      elsif Key = Guikit.Input.Key_Delete and then Modifiers = Guikit.Input.No_Modifiers then
         --  Delete resets the binding to its built-in default. The armed field's
         --  key is "shortcut.<identifier>"; feeding the default's Shortcut_Text
         --  makes Apply clear the override, so a default binding persists nothing.
         declare
            Field_Key : constant String := Files.Model.Settings_Capturing_Key (Model);
            Prefix    : constant String := "shortcut.";
            function Default_Text return String is
            begin
               if Field_Key'Length > Prefix'Length
                 and then Field_Key (Field_Key'First .. Field_Key'First + Prefix'Length - 1) = Prefix
               then
                  declare
                     Id : constant Files.Commands.Command_Id :=
                       Files.Commands.Id_For_Identifier
                         (Field_Key (Field_Key'First + Prefix'Length .. Field_Key'Last));
                  begin
                     if Id in Files.Commands.Registered_Command_Id then
                        return Files.Commands.Shortcut_Text (Files.Commands.Default_Shortcut_For (Id));
                     end if;
                  end;
               end if;
               return "";
            end Default_Text;
         begin
            Files.Model.Settings_Set_Captured_Shortcut (Model, Default_Text);
         end;
         return Applied_Settings_Change (Model);
      elsif Key = Guikit.Input.Key_Unknown then
         --  A key with no chord representation: ignore it and stay armed.
         return Make_Result (Controller_Ignored);
      else
         Files.Model.Settings_Set_Captured_Shortcut
           (Model,
            Files.Commands.Shortcut_Text
              (Files.Commands.Shortcut'(Present => True, Key => Key, Modifiers => Modifiers)));
         return Applied_Settings_Change (Model);
      end if;
   end Capture_Settings_Shortcut;

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
   is
      Operation : Files.Operations.Operation_Result := Empty_Operation;
   begin
      case Files.Model.Focus (Model) is
         when Files.Types.Focus_Path_Input =>
            Operation := Files.Operations.Commit_Path_Input (Model, Settings);
            return Make_Result (Controller_Command_Executed, Files.Commands.Focus_Path_Input_Command, Operation);
         when Files.Types.Focus_Filter_Input =>
            Files.Model.Cancel_Focus_Or_Edit (Model);
            Operation.Status := Files.Operations.Operation_Success;
            return Make_Result (Controller_Command_Executed, Files.Commands.Focus_Filter_Input_Command, Operation);
         when Files.Types.Focus_Rename_Input =>
            if Files.Model.Temporary_Item_Is_Active (Model) then
               Operation := Files.Operations.Commit_Create_File (Model, Settings);
            else
               Operation := Files.Operations.Commit_Rename (Model, Settings);
            end if;
            return Make_Result (Controller_Command_Executed, Files.Commands.Rename_Selected_Items_Command, Operation);
         when Files.Types.Focus_Command_Palette =>
            return Activate_Palette_Command (Model, Settings, Modifiers);
         when Files.Types.Focus_Settings_Input =>
            declare
               Parsed : constant Files.Settings.Settings_Parse_Result :=
                 Files.Settings.Validate_Draft (Files.Model.Settings_Draft_Of (Model));
               Draft  : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
            begin
               if Parsed.Success then
                  Draft.Valid := True;
                  Draft.Error_Key := Null_Unbounded_String;
                  Files.Model.Set_Error (Model, "");
                  Operation.Status := Files.Operations.Operation_Success;
               else
                  Draft.Valid := False;
                  Draft.Error_Key := Parsed.Error_Key;
                  Files.Model.Set_Error (Model, To_String (Parsed.Error_Key));
                  Operation.Status := Files.Operations.Operation_Failed;
                  Operation.Error_Key := Parsed.Error_Key;
               end if;
               Files.Model.Set_Settings_Draft (Model, Draft);
            end;
            return
              Make_Result
                (Controller_Command_Executed,
                 Files.Commands.Toggle_Settings_Pane_Command,
                 Operation);
         when Files.Types.Focus_Ownership_Input =>
            declare
               Raw   : constant String :=
                 Ada.Strings.Fixed.Trim (Files.Model.Ownership_Input_Text (Model), Ada.Strings.Both);
               Group : constant Boolean := Files.Model.Ownership_Editing_Group (Model);
               Item  : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
               Resolved : Natural := 0;
               Found    : Boolean := False;

               function Is_Numeric (Text : String) return Boolean is
               begin
                  if Text'Length = 0 then
                     return False;
                  end if;
                  for Ch of Text loop
                     if Ch not in '0' .. '9' then
                        return False;
                     end if;
                  end loop;
                  return True;
               end Is_Numeric;
            begin
               if Is_Numeric (Raw) then
                  begin
                     Resolved := Natural'Value (Raw);
                     Found := True;
                  exception
                     when others =>
                        Found := False;
                  end;
               elsif Group then
                  Resolved := Files.File_System.Group_Id_For_Name (Raw, Found);
               else
                  Resolved := Files.File_System.User_Id_For_Name (Raw, Found);
               end if;

               if not Found then
                  Files.Model.Set_Error (Model, "error.ownership.invalid_name");
                  Files.Model.Cancel_Focus_Or_Edit (Model);
                  Operation.Status := Files.Operations.Operation_Failed;
                  Operation.Error_Key := To_Unbounded_String ("error.ownership.invalid_name");
                  return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
               end if;

               if Group then
                  Operation :=
                    Files.Operations.Set_Ownership_For (Model, Item.Owner_Id, Resolved, Settings);
               else
                  Operation :=
                    Files.Operations.Set_Ownership_For (Model, Resolved, Item.Group_Id, Settings);
               end if;
               Files.Model.Cancel_Focus_Or_Edit (Model);
               return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Operation);
            end;
         when others =>
            return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
      end case;
   end Commit_Focused_Text;

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
   is
      Action : constant Files.Events.Input_Action := Files.Events.Translate_Key (Key, Modifiers);

      function Control_Only return Boolean is
      begin
         return Modifiers (Guikit.Input.Control_Key)
           and then not Modifiers (Guikit.Input.Shift_Key)
           and then not Modifiers (Guikit.Input.Alt_Key)
           and then not Modifiers (Guikit.Input.Meta_Key);
      end Control_Only;
   begin
      --  While a long paste is running the progress overlay owns the keyboard:
      --  Escape requests cancellation (already-copied files are kept) and every
      --  other key is swallowed so no command runs behind the modal-lite panel.
      if Files.Model.Paste_Execution_Is_Active (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Operations.Cancel_Paste_Execution (Model);
            declare
               Finalized : constant Files.Operations.Operation_Result :=
                 Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            begin
               return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Finalized);
            end;
         end if;
         return Make_Result (Controller_Ignored);
      end if;

      --  While the paste-conflict dialog is open it owns the keyboard: Escape
      --  cancels the whole paste and every other key is swallowed so no command
      --  runs behind the modal.
      if Files.Model.Paste_Conflict_Is_Active (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            declare
               Cancelled : constant Files.Operations.Operation_Result :=
                 Files.Operations.Resolve_Paste_Conflict
                   (Model     => Model,
                    Settings  => Settings,
                    Choice    => Files.Operations.Choice_Cancel,
                    Apply_All => False);
            begin
               return Make_Result (Controller_Command_Executed, Files.Commands.No_Command, Cancelled);
            end;
         end if;
         return Make_Result (Controller_Ignored);
      end if;

      --  While the Quick Look overlay is open it owns the keyboard: Escape or
      --  Space close it and every other key is swallowed so nothing behind the
      --  modal-lite preview reacts.
      if Files.Model.Quick_Look_Is_Open (Model) then
         if (Key = Guikit.Input.Key_Escape or else Key = Guikit.Input.Key_Space)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            Files.Model.Close_Quick_Look (Model);
            return Successful_Command_Result (Files.Commands.Toggle_Quick_Look_Command);
         end if;
         return Make_Result (Controller_Ignored);
      end if;

      if Files.Model.Command_Palette_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Command_Palette (Model);
            return Make_Result (Controller_Palette_Updated, Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            return Commit_Focused_Text (Model, Settings, Modifiers);
         elsif Key = Guikit.Input.Key_Left and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, -1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Right and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, 1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, -1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Move_Selection (Model, 1);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Home and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Select_First (Model);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_End and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Select_Last (Model);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Page_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Page (Model, Down => False);
            return Make_Result (Controller_Palette_Updated);
         elsif Key = Guikit.Input.Key_Page_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Palette_Page (Model, Down => True);
            return Make_Result (Controller_Palette_Updated);
         end if;
      end if;

      if Files.Model.Root_Selector_Is_Open (Model) then
         if Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Close_Root_Selector (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            return Handle_Root_Click (Model, Settings, Files.Model.Root_Selected_Index (Model));
         elsif Key = Guikit.Input.Key_Left and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Left);
         elsif Key = Guikit.Input.Key_Right and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Right);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Up);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Selection_Result (Model, Guikit.Input.Move_Down);
         elsif Key = Guikit.Input.Key_Home and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Jump_Result (Model, 1);
         elsif Key = Guikit.Input.Key_End and then Modifiers = Guikit.Input.No_Modifiers then
            return Root_Jump_Result (Model, Files.Model.Root_Count (Model));
         elsif Action.Kind = Files.Events.Command_Input_Action
           and then Action.Command = Files.Commands.Open_Command_Palette_Command
         then
            null;
         else
            return Make_Result (Controller_Ignored);
         end if;
      end if;

      if Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input then
         if Files.Model.Settings_Is_Capturing (Model) then
            --  A Shortcut row is armed: every key is a chord to capture, not a
            --  navigation or shortcut, until the capture ends.
            return Capture_Settings_Shortcut (Model, Key, Modifiers);
         elsif Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Toggle_Settings_Pane (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Guikit.Input.Key_Up and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Settings_Move_Focus (Model, -1);
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif Key = Guikit.Input.Key_Down and then Modifiers = Guikit.Input.No_Modifiers then
            Files.Model.Settings_Move_Focus (Model, 1);
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif (Key = Guikit.Input.Key_Left or else Key = Guikit.Input.Key_Right)
           and then Modifiers = Guikit.Input.No_Modifiers
         then
            --  Left/Right cycle the focused toggle/choice or step a number (a
            --  no-op on text fields); the emitted change is applied to the draft.
            Files.Model.Settings_Cycle_Choice (Model, Forward => Key = Guikit.Input.Key_Right);
            return Applied_Settings_Change (Model);
         elsif Key = Guikit.Input.Key_Tab
           and then Modifiers (Guikit.Input.Control_Key)
           and then not Modifiers (Guikit.Input.Alt_Key)
           and then not Modifiers (Guikit.Input.Meta_Key)
         then
            --  Ctrl+Tab / Ctrl+Shift+Tab switch between the section tabs -- the
            --  keyboard equivalent of clicking the tab switcher.
            Cycle_Settings_Section (Model, Forward => not Modifiers (Guikit.Input.Shift_Key));
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif Key = Guikit.Input.Key_Return and then Modifiers = Guikit.Input.No_Modifiers then
            --  Enter on a focused Shortcut row arms press-to-capture (the
            --  keyboard equivalent of clicking it); otherwise fall through to the
            --  general Return handling below.
            Files.Model.Settings_Begin_Capture (Model);
            if Files.Model.Settings_Is_Capturing (Model) then
               return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
            end if;
         end if;
      end if;

      if Key = Guikit.Input.Key_Return then
         if Modifiers = Guikit.Input.No_Modifiers then
            return Commit_Focused_Text (Model, Settings, Modifiers);
         elsif Files.Model.Focus (Model) = Files.Types.Focus_None then
            return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
         end if;
      elsif Key = Guikit.Input.Key_Backspace
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Word_Backward (Model);
      elsif Key = Guikit.Input.Key_Delete
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Word_Forward (Model);
      elsif Key = Guikit.Input.Key_Left
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets_Word (Model, Guikit.Input.Move_Left)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position
              (Model, Previous_Word_Boundary (Focused_Text (Model), Old_Position));
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Right
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets_Word (Model, Guikit.Input.Move_Right)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position
              (Model, Next_Word_Boundary (Focused_Text (Model), Old_Position));
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Backspace
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Backward (Model);
      elsif Key = Guikit.Input.Key_Delete
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Forward (Model);
      elsif Key = Guikit.Input.Key_Left
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Left)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Left);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Right
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Move_Text_Cursor (Model, Guikit.Input.Move_Right);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Home
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         --  Plain Home in the file grid selects the first visible item. This has
         --  no modifier, so it never collides with Alt+Home = navigate home.
         return First_Selection_Result (Model);
      elsif Key = Guikit.Input.Key_End
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         --  Plain End in the file grid selects the last visible item.
         return Last_Selection_Result (Model);
      elsif Key = Guikit.Input.Key_Home
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Set_All_Carets_Home (Model)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position (Model, 0);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_End
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Set_All_Carets_End (Model)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Set_Text_Cursor_Position (Model, Focused_Text (Model)'Length);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Guikit.Input.Key_Page_Up
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         --  With the info pane open Page Up scrolls it; over the file grid it
         --  pages the selection up by a page (like the arrow keys move it).
         if Files.Model.Info_Pane_Is_Open (Model) then
            return Scroll_Info_Result (Model, -10);
         else
            return Page_Selection_Result (Model, Down => False);
         end if;
      elsif Key = Guikit.Input.Key_Page_Down
        and then Modifiers = Guikit.Input.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         if Files.Model.Info_Pane_Is_Open (Model) then
            return Scroll_Info_Result (Model, 10);
         else
            return Page_Selection_Result (Model, Down => True);
         end if;
      elsif Key = Guikit.Input.Key_Escape and then Modifiers = Guikit.Input.No_Modifiers then
         if Files.Model.Focus (Model) = Files.Types.Focus_None
           and then not Files.Model.Rename_Is_Active (Model)
           and then not Files.Model.Temporary_Item_Is_Active (Model)
         then
            if Files.Model.Settings_Pane_Is_Open (Model) then
               Files.Model.Toggle_Settings_Pane (Model);
               return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
            else
               return Make_Result (Controller_Ignored, Files.Commands.Close_Command_Palette_Command);
            end if;
         else
            Files.Model.Cancel_Focus_Or_Edit (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         end if;
      end if;

      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if Action.Command = Files.Commands.Toggle_Quick_Look_Command
              and then Files.Model.Focus (Model) /= Files.Types.Focus_None
            then
               --  Space is the Quick Look shortcut only when the grid owns the
               --  keyboard. With a text field focused it is a typed space, so
               --  ignore the shortcut and let the character event handle it.
               return Make_Result (Controller_Ignored);
            end if;
            return Execute_Command (Action.Command, Model, Settings, Modifiers);
         when Files.Events.Selection_Input_Action =>
            if Files.Model.Focus (Model) = Files.Types.Focus_None
              and then not Files.Model.Settings_Pane_Is_Open (Model)
            then
               declare
                  Old_Index : constant Natural := Files.Model.Selected_Index (Model);
                  Old_Count : constant Natural := Files.Model.Selected_Count (Model);
                  Anchor    : Natural := Old_Index;
               begin
                  if Action.Range_Selection and then Old_Count > 1 then
                     declare
                        First_Selected : Natural := 0;
                        Last_Selected  : Natural := 0;
                     begin
                        for Index in 1 .. Files.Model.Visible_Count (Model) loop
                           if Files.Model.Is_Selected (Model, Positive (Index)) then
                              if First_Selected = 0 then
                                 First_Selected := Index;
                              end if;
                              Last_Selected := Index;
                           end if;
                        end loop;

                        if Old_Index = Last_Selected then
                           Anchor := First_Selected;
                        elsif Old_Index = First_Selected then
                           Anchor := Last_Selected;
                        end if;
                     end;
                  end if;

                  Files.Model.Move_Selection (Model, Action.Direction);
                  if Action.Range_Selection then
                     declare
                        New_Index : constant Natural := Files.Model.Selected_Index (Model);
                     begin
                        if Anchor > 0 and then New_Index > 0 then
                           Files.Model.Select_Visible_Range (Model, Positive (Anchor), Positive (New_Index));
                        end if;
                     end;
                  end if;
                  return
                    Make_Result
                      (if Files.Model.Selected_Index (Model) = Old_Index
                         and then Files.Model.Selected_Count (Model) = Old_Count
                       then Controller_Ignored
                       else Controller_Selection_Moved);
               end;
            end if;
         when Files.Events.Scroll_Input_Action =>
            return Handle_Scroll (Model, Action.Scroll_Lines);
         when Files.Events.No_Input_Action
            | Files.Events.Text_Click_Input_Action
            | Files.Events.Settings_Click_Input_Action
            | Files.Events.Item_Click_Input_Action
            | Files.Events.Root_Click_Input_Action
            | Files.Events.Breadcrumb_Click_Input_Action
            | Files.Events.Path_Favorite_Toggle_Input_Action
            | Files.Events.Tree_Click_Input_Action
            | Files.Events.Tree_Pick_Confirm_Input_Action
            | Files.Events.Command_Result_Click_Input_Action
            | Files.Events.Scrollbar_Drag_Begin_Input_Action
            | Files.Events.Column_Resize_Begin_Input_Action
            | Files.Events.Column_Reorder_Begin_Input_Action
            | Files.Events.Marquee_Begin_Input_Action
            | Files.Events.Permission_Toggle_Input_Action
            | Files.Events.Ownership_Edit_Input_Action
            | Files.Events.Conflict_Click_Input_Action
            | Files.Events.Label_Picker_Choice_Input_Action
            | Files.Events.Search_Scope_Toggle_Input_Action
            | Files.Events.Paste_Cancel_Input_Action =>
            null;
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Key;

end Files.Controller;
