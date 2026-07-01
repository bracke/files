with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.Applications;
with Files.Breadcrumbs;
with Files.Command_Palette;
with Files.Folder_Tree;
with Files.UTF8;

package body Files.Controller is
   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Files.Types.Key_Code;
   use type Files.Types.Modifier_Set;
   use type Files.Types.Navigation_Direction;
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

   procedure Set_Palette_Selection
     (Model : in out Files.Model.Window_Model;
      Index : Natural;
      Count : Natural);

   procedure Reconcile_Palette_Selection (Model : in out Files.Model.Window_Model) is
      Results : constant Files.Command_Palette.Result_Vectors.Vector :=
        Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
      Count   : constant Natural := Natural (Results.Length);
      Index   : Natural := Files.Model.Command_Palette_Selected_Index (Model);
   begin
      if Results.Is_Empty then
         Files.Model.Set_Command_Palette_Selected_Index (Model, 0);
         Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
         return;
      end if;

      if Index = 0 or else Index > Count then
         Index := 1;
      end if;

      Set_Palette_Selection (Model, Index, Count);
   end Reconcile_Palette_Selection;

   procedure Set_Palette_Selection
     (Model : in out Files.Model.Window_Model;
      Index : Natural;
      Count : Natural)
   is
      Visible_Rows : constant Natural := 4;
      Offset       : Natural := Files.Model.Command_Palette_Result_Offset (Model);
   begin
      if Count = 0 or else Index = 0 then
         Files.Model.Set_Command_Palette_Selected_Index (Model, 0);
         Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
         return;
      end if;

      if Count <= Visible_Rows then
         Offset := 0;
      elsif Offset > Count - Visible_Rows then
         Offset := Count - Visible_Rows;
      end if;

      if Index <= Offset then
         Offset := Index - 1;
      elsif Index > Offset + Visible_Rows then
         Offset := Index - Visible_Rows;
      end if;

      Files.Model.Set_Command_Palette_Selected_Index (Model, Index);
      Files.Model.Set_Command_Palette_Result_Offset (Model, Offset);
   end Set_Palette_Selection;

   procedure Move_Palette_Selection
     (Model     : in out Files.Model.Window_Model;
      Direction : Files.Types.Navigation_Direction)
   is
      Results : constant Files.Command_Palette.Result_Vectors.Vector :=
        Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
      Count   : constant Natural := Natural (Results.Length);
      Current : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
      Next    : Natural := 0;
   begin
      if Count = 0 then
         Files.Model.Set_Command_Palette_Selected_Index (Model, 0);
         Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
         return;
      elsif Current = 0 or else Current > Count then
         Next := 1;
      elsif Direction = Files.Types.Move_Up or else Direction = Files.Types.Move_Left then
         Next := (if Current = 1 then Count else Current - 1);
      else
         Next := (if Current = Count then 1 else Current + 1);
      end if;

      Set_Palette_Selection (Model, Next, Count);
   end Move_Palette_Selection;

   function Palette_Scroll_Steps
     (Lines : Integer;
      Count : Natural)
      return Natural
   is
      Magnitude : constant Natural :=
        (if Lines = Integer'First then Natural'Last else Natural (abs Lines));
      Remainder : constant Natural := (if Count = 0 then 0 else Magnitude mod Count);
   begin
      if Count = 0 or else Magnitude = 0 then
         return 0;
      elsif Remainder = 0 then
         return 1;
      end if;

      return Remainder;
   end Palette_Scroll_Steps;

   procedure Scroll_Palette_Selection
     (Model : in out Files.Model.Window_Model;
      Lines : Integer)
   is
      Results   : constant Files.Command_Palette.Result_Vectors.Vector :=
        Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
      Count     : constant Natural := Natural (Results.Length);
      Steps     : constant Natural := Palette_Scroll_Steps (Lines, Count);
   begin
      if Count = 0 then
         Files.Model.Set_Command_Palette_Selected_Index (Model, 0);
         Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
         return;
      end if;

      for Step in 1 .. Steps loop
         Move_Palette_Selection
           (Model,
            (if Lines > 0 then Files.Types.Move_Down else Files.Types.Move_Up));
      end loop;
   end Scroll_Palette_Selection;

   procedure Jump_Palette_Selection
     (Model : in out Files.Model.Window_Model;
      Last  : Boolean)
   is
      Results : constant Files.Command_Palette.Result_Vectors.Vector :=
        Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
      Count   : constant Natural := Natural (Results.Length);
      Index   : Natural := 0;
   begin
      if Count = 0 then
         Files.Model.Set_Command_Palette_Selected_Index (Model, 0);
         Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
         return;
      end if;

      Index := (if Last then Count else 1);
      Set_Palette_Selection (Model, Index, Count);
   end Jump_Palette_Selection;

   procedure Page_Palette_Selection
     (Model : in out Files.Model.Window_Model;
      Down  : Boolean)
   is
      Results : constant Files.Command_Palette.Result_Vectors.Vector :=
        Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
      Count   : constant Natural := Natural (Results.Length);
      Current : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
      Step    : constant Natural := 4;
      Next    : Natural := 0;
   begin
      if Count = 0 then
         Files.Model.Set_Command_Palette_Selected_Index (Model, 0);
         Files.Model.Set_Command_Palette_Result_Offset (Model, 0);
         return;
      elsif Current = 0 or else Current > Count then
         Next := 1;
      elsif Down then
         Next := (if Current > Count - Natural'Min (Step, Count) then Count else Current + Step);
      elsif Current <= Step then
         Next := 1;
      else
         Next := Current - Step;
      end if;

      Set_Palette_Selection (Model, Next, Count);
   end Page_Palette_Selection;

   function Palette_Selection_Result
     (Model      : Files.Model.Window_Model;
      Old_Index  : Natural;
      Old_Offset : Natural)
      return Controller_Result
   is
   begin
      return
        Make_Result
          (if Files.Model.Command_Palette_Selected_Index (Model) = Old_Index
             and then Files.Model.Command_Palette_Result_Offset (Model) = Old_Offset
           then Controller_Ignored
           else Controller_Palette_Updated);
   end Palette_Selection_Result;

   function Settings_Drafts_Equal
     (Left  : Files.Settings.Settings_Draft;
      Right : Files.Settings.Settings_Draft)
      return Boolean is
   begin
      return Left.Default_View_Mode = Right.Default_View_Mode
        and then Left.Show_Hidden_Files = Right.Show_Hidden_Files
        and then Left.Sort_Field_Value = Right.Sort_Field_Value
        and then Left.Sort_Ascending = Right.Sort_Ascending
        and then Left.Theme = Right.Theme
        and then Left.Icon_Theme_Name = Right.Icon_Theme_Name
        and then Left.Filetype_Extension = Right.Filetype_Extension
        and then Left.Filetype_Value = Right.Filetype_Value
        and then Left.Filetype_Keys = Right.Filetype_Keys
        and then Left.Filetype_Values = Right.Filetype_Values
        and then Left.Filetype_Index = Right.Filetype_Index
        and then Left.Icon_Filetype = Right.Icon_Filetype
        and then Left.Icon_Value = Right.Icon_Value
        and then Left.Icon_Keys = Right.Icon_Keys
        and then Left.Icon_Values = Right.Icon_Values
        and then Left.Icon_Index = Right.Icon_Index
        and then Left.Open_Action_Token = Right.Open_Action_Token
        and then Left.Open_Action_Command = Right.Open_Action_Command
        and then Left.Open_Action_Keys = Right.Open_Action_Keys
        and then Left.Open_Action_Commands = Right.Open_Action_Commands
        and then Left.Open_Action_Index = Right.Open_Action_Index
        and then Left.Error_Key = Right.Error_Key
        and then Left.Valid = Right.Valid;
   end Settings_Drafts_Equal;

   function Settings_Update_Result
     (Model      : Files.Model.Window_Model;
      Old_Draft  : Files.Settings.Settings_Draft;
      Old_Field  : Natural;
      Old_Text   : String;
      Old_Cursor : Natural)
      return Controller_Result
   is
      Draft : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
   begin
      return
        Make_Result
          ((if Files.Model.Settings_Field_Index (Model) = Old_Field
              and then Files.Model.Settings_Field_Text (Model) = Old_Text
              and then Files.Model.Text_Cursor_Position (Model) = Old_Cursor
              and then Settings_Drafts_Equal (Draft, Old_Draft)
            then Controller_Ignored
            else Controller_Text_Updated),
           Files.Commands.Toggle_Settings_Pane_Command);
   end Settings_Update_Result;

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
            Files.Model.Set_Command_Palette_Query (Model, Text);
            Reconcile_Palette_Selection (Model);
         when Files.Types.Focus_Settings_Input =>
            Files.Model.Set_Settings_Field_Text (Model, Text);
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
            return Files.Model.Command_Palette_Query (Model);
         when Files.Types.Focus_Settings_Input =>
            return Files.Model.Settings_Field_Text (Model);
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
      if Files.Model.Focus (Model) = Files.Types.Focus_None or else Text = "" then
         return Make_Result (Controller_Ignored);
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

   function Execute_Command
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
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
         when Files.Commands.Navigate_Trash_Command =>
            Operation := Files.Operations.Navigate_Trash (Model, Settings);
         when Files.Commands.Restore_From_Trash_Command =>
            Operation := Files.Operations.Restore_Selected_From_Trash (Model, Settings);
         when Files.Commands.Undo_Command =>
            Operation := Files.Operations.Undo_Last (Model, Settings);
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
               Files.Model.Set_Command_Palette_Query (Model, "");
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
               Operation :=
                 Files.Operations.Import_Dropped_Paths
                   (Model, Settings, Paths, Drop_Mode);
               if Operation.Status = Files.Operations.Operation_Success
                 and then Mode = Files.Model.Clipboard_Cut
               then
                  Files.Model.Clear_Clipboard (Model);
               end if;
            end;
         when Files.Commands.Generate_Thumbnails_Command =>
            Operation := Files.Operations.Generate_Selected_Thumbnails (Model, Settings);
         when Files.Commands.Search_Recursive_Command =>
            Operation := Files.Operations.Run_Recursive_Search (Model, Settings);
         when Files.Commands.Refresh_Directory_Command =>
            Operation := Files.Operations.Refresh (Model, Settings);
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
                  for Path of Settings.Bookmark_Paths loop
                     Roots.Append
                       (Files.File_System.Root_Entry'
                          (Path        => Path,
                           Label       => Path,
                           Kind        => Files.File_System.Root_Bookmark,
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
               if not Files.Model.Tree_Is_Seeded (Model) then
                  declare
                     Roots : Files.File_System.Root_Entry_Vectors.Vector :=
                       Files.File_System.Available_Root_Entries;
                     Seeds : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
                  begin
                     for Path of Settings.Bookmark_Paths loop
                        Roots.Append
                          (Files.File_System.Root_Entry'
                             (Path        => Path,
                              Label       => Path,
                              Kind        => Files.File_System.Root_Bookmark,
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
               Files.Model.Open_Tree_Panel (Model);
            end if;
            Files.Model.Set_Error (Model, "");
         when Files.Commands.Reset_Settings_Command =>
            Files.Model.Set_Settings_Draft (Model, Files.Settings.Reset_Draft_To_Defaults);
            Files.Model.Set_Settings_Field_Index (Model, 1);
            Files.Model.Set_Error (Model, "");
            Operation.Status := Files.Operations.Operation_Success;
         when Files.Commands.Close_Command_Palette_Command =>
            if Files.Model.Context_Menu_Is_Open (Model) then
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

   function Save_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Controller_Result
   is
      Applied : constant Files.Settings.Settings_Parse_Result :=
        Files.Settings.Apply_Draft (Settings, Files.Model.Settings_Draft_Of (Model));
      Saved   : Files.Settings.Settings_Write_Result;
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

      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Applied.Settings));
      if not Saved.Success then
         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));
         Operation.Status := Files.Operations.Operation_Failed;
         Operation.Error_Key := Saved.Error_Key;
         Operation.Path := To_Unbounded_String (Settings_Path);
         return Make_Result (Controller_Command_Executed, Files.Commands.Save_Settings_Command, Operation);
      end if;

      Settings := Applied.Settings;
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

   function Handle_Command_Click
     (Id        : Files.Commands.Command_Id;
      Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result is
   begin
      if Id = Files.Commands.No_Command then
         return Make_Result (Controller_Ignored);
      end if;

      return Execute_Command (Id, Model, Settings, Modifiers);
   end Handle_Command_Click;

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
         Operation : constant Files.Operations.Operation_Result :=
           Files.Operations.Select_Root (Model, Settings, Files.Model.Root_Path (Model, Positive (Root_Index)));
      begin
         return Make_Result (Controller_Command_Executed, Files.Commands.Open_Selected_Root_Command, Operation);
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

   --  Launch the application carried by an "Open With" palette result on the
   --  stored target paths, then close the palette. The detached spawn status is
   --  advisory only (the wrapper shell, not the real handler), mirroring
   --  Open_Selected's detached-launch policy.
   function Launch_Application_Result
     (Model : in out Files.Model.Window_Model;
      Item  : Files.Command_Palette.Result_Entry)
      return Controller_Result
   is
      App : constant Files.Applications.Application :=
        (Name => Item.Application_Name, Exec => Item.Application_Exec);
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

   function Handle_Command_Result_Click
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Result_Index : Natural;
      Modifiers    : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result
   is
      Results : constant Files.Command_Palette.Result_Vectors.Vector :=
        Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
   begin
      if not Files.Model.Command_Palette_Is_Open (Model)
        or else Result_Index = 0
        or else Result_Index > Natural (Results.Length)
      then
         return Make_Result (Controller_Ignored);
      end if;

      Files.Model.Set_Command_Palette_Selected_Index (Model, Result_Index);

      if Results.Element (Positive (Result_Index)).Is_Application then
         return Launch_Application_Result (Model, Results.Element (Positive (Result_Index)));
      end if;

      if not Results.Element (Positive (Result_Index)).Enabled then
         return Execute_Command (Results.Element (Positive (Result_Index)).Command, Model, Settings, Modifiers);
      end if;

      declare
         Command : constant Files.Commands.Command_Id :=
           Results.Element (Positive (Result_Index)).Command;
         Result : constant Controller_Result :=
           Execute_Command (Command, Model, Settings, Modifiers);
      begin
         --  Open_With re-opens the palette in application-picker mode, so leave
         --  it open instead of closing it immediately after execution.
         if Result.Status /= Controller_Ignored
           and then Command /= Files.Commands.Open_With_Command
         then
            Files.Model.Close_Command_Palette (Model);
         end if;
         return Result;
      end;
   end Handle_Command_Result_Click;

   function Handle_Item_Click
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Visible_Index : Natural;
      Activate      : Boolean := False;
      Modifiers     : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
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

      if Modifiers (Files.Types.Shift_Key) and then not Activate then
         declare
            Anchor : constant Natural := Files.Model.Selected_Index (Model);
         begin
            Files.Model.Select_Visible_Range
              (Model,
               Positive ((if Anchor = 0 then Visible_Index else Anchor)),
               Positive (Visible_Index));
         end;
      elsif Modifiers (Files.Types.Control_Key) and then not Activate then
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
      Operation : constant Files.Operations.Operation_Result :=
        Files.Operations.Import_Dropped_Paths (Model, Settings, Source_Paths, Mode);
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
      return Controller_Result
   is
      Old_Lines : constant Natural := Files.Model.Settings_Pane_Scroll_Lines (Model);
   begin
      Files.Model.Scroll_Settings_Pane (Model, Lines);
      return
        Make_Result
          (if Files.Model.Settings_Pane_Scroll_Lines (Model) = Old_Lines
           then Controller_Ignored
           else Controller_Command_Executed);
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
         if Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model).Is_Empty then
            return Make_Result (Controller_Ignored);
         else
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Scroll_Palette_Selection (Model, Lines);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
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
               if Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model).Is_Empty then
                  return Make_Result (Controller_Ignored);
               else
                  declare
                     Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
                     Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
                  begin
                     Scroll_Palette_Selection (Model, Lines);
                     return Palette_Selection_Result (Model, Old_Index, Old_Offset);
                  end;
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
            Files.Model.Set_Settings_Field_Index (Model, Files.Model.Settings_Field_Index (Model));
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

   function Handle_Settings_Click
     (Model  : in out Files.Model.Window_Model;
      Field  : Natural;
      Option : Natural := 0)
      return Controller_Result
   is
      function Valid_Option return Boolean is
      begin
         if Option = 0 then
            return True;
         elsif Option = 100 or else Option = 101 then
            return Field in 8 | 10 | 12;
         elsif Option = 150 or else Option = 151 then
            return Field = 7;
         end if;

         case Field is
            when 1 =>
               return Option in 1 .. 3;
            when 2 | 4 | 5 | 6 =>
               return Option in 1 .. 2;
            when 3 =>
               return Option in 1 .. 5;
            when others =>
               return False;
         end case;
      end Valid_Option;
   begin
      if Files.Model.Command_Palette_Is_Open (Model)
        or else not Files.Model.Settings_Pane_Is_Open (Model)
        or else Field = 0
        or else Field > 13
        or else not Valid_Option
      then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Old_Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
         Old_Field  : constant Natural := Files.Model.Settings_Field_Index (Model);
         Old_Text   : constant String := Files.Model.Settings_Field_Text (Model);
         Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
         Stepper_No_Op : Boolean := False;
      begin
         Files.Model.Set_Settings_Field_Index (Model, Field);
         if Option = 100 then
            Files.Model.Add_Settings_Entry (Model);
         elsif Option = 101 then
            Files.Model.Remove_Settings_Entry (Model);
         elsif Option = 150 or else Option = 151 then
            declare
               Min_Px : constant := 10;
               Max_Px : constant := 32;
               Step   : constant Integer := (if Option = 151 then 1 else -1);
               Current_N : Integer := 16;
               Next_N    : Integer;
            begin
               begin
                  Current_N := Integer'Value (Files.Model.Settings_Field_Text (Model));
               exception
                  when Constraint_Error =>
                     Current_N := 16;
               end;
               Next_N := Current_N + Step;
               if Next_N < Min_Px then
                  Next_N := Min_Px;
               elsif Next_N > Max_Px then
                  Next_N := Max_Px;
               end if;
               if Next_N /= Current_N then
                  Files.Model.Set_Settings_Field_Text
                    (Model,
                     Ada.Strings.Fixed.Trim
                       (Integer'Image (Next_N), Ada.Strings.Both));
               else
                  Stepper_No_Op := True;
               end if;
            end;
         elsif Option > 0 then
            case Field is
               when 1 =>
                  case Option is
                     when 1 => Files.Model.Set_Settings_Field_Text (Model, "small_icons");
                     when 2 => Files.Model.Set_Settings_Field_Text (Model, "large_icons");
                     when 3 => Files.Model.Set_Settings_Field_Text (Model, "details");
                     when others => null;
                  end case;
               when 2 | 4 =>
                  Files.Model.Set_Settings_Field_Text (Model, (if Option = 1 then "true" else "false"));
               when 5 =>
                  case Option is
                     when 1 => Files.Model.Set_Settings_Field_Text (Model, "dark");
                     when 2 => Files.Model.Set_Settings_Field_Text (Model, "light");
                     when 3 => Files.Model.Set_Settings_Field_Text (Model, "high_contrast");
                     when others => null;
                  end case;
               when 6 =>
                  Files.Model.Set_Settings_Field_Text
                    (Model, (if Option = 1 then "files-basic" else "files-high-contrast"));
               when 3 =>
                  case Option is
                     when 1 => Files.Model.Set_Settings_Field_Text (Model, "name");
                     when 2 => Files.Model.Set_Settings_Field_Text (Model, "filetype");
                     when 3 => Files.Model.Set_Settings_Field_Text (Model, "size");
                     when 4 => Files.Model.Set_Settings_Field_Text (Model, "modified");
                     when 5 => Files.Model.Set_Settings_Field_Text (Model, "created");
                     when others => null;
                  end case;
               when others =>
                  null;
            end case;
         end if;

         if Stepper_No_Op then
            --  Font-size stepper already at its min/max bound: nothing changed,
            --  so do not report a redundant save.
            return Make_Result (Controller_Ignored);
         elsif Option > 0 then
            return
              Make_Result
                (Controller_Command_Executed, Files.Commands.Save_Settings_Command);
         end if;

         return Settings_Update_Result (Model, Old_Draft, Old_Field, Old_Text, Old_Cursor);
      end;
   end Handle_Settings_Click;

   function Commit_Focused_Text
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Files.Types.Modifier_Set)
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
            declare
               Results : constant Files.Command_Palette.Result_Vectors.Vector :=
                 Files.Command_Palette.Search (Files.Model.Command_Palette_Query (Model), Model);
               Index   : Natural := Files.Model.Command_Palette_Selected_Index (Model);
            begin
               if Results.Is_Empty then
                  return Make_Result (Controller_Ignored);
               elsif Index = 0 or else Index > Natural (Results.Length) then
                  Index := 1;
                  Files.Model.Set_Command_Palette_Selected_Index (Model, Index);
               end if;

               if Index <= Natural (Results.Length)
                 and then Results.Element (Positive (Index)).Is_Application
               then
                  return Launch_Application_Result (Model, Results.Element (Positive (Index)));
               elsif Index <= Natural (Results.Length) and then Results.Element (Positive (Index)).Enabled then
                  declare
                     Command : constant Files.Commands.Command_Id :=
                       Results.Element (Positive (Index)).Command;
                     Command_Result : constant Controller_Result :=
                       Execute_Command (Command, Model, Settings, Modifiers);
                  begin
                     --  Open_With re-opens the palette in application-picker
                     --  mode, so leave it open instead of closing it.
                     if Command_Result.Status /= Controller_Ignored
                       and then Command /= Files.Commands.Open_With_Command
                     then
                        Files.Model.Close_Command_Palette (Model);
                     end if;
                     return Command_Result;
                  end;
               elsif Index <= Natural (Results.Length) then
                  return Execute_Command (Results.Element (Positive (Index)).Command, Model, Settings, Modifiers);
               end if;
            end;
            return Make_Result (Controller_Ignored);
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
         when others =>
            return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
      end case;
   end Commit_Focused_Text;

   function Root_Selection_Result
     (Model     : in out Files.Model.Window_Model;
      Direction : Files.Types.Navigation_Direction)
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

   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Files.Types.Key_Code;
      Modifiers : Files.Types.Modifier_Set := Files.Types.No_Modifiers)
      return Controller_Result
   is
      Action : constant Files.Events.Input_Action := Files.Events.Translate_Key (Key, Modifiers);

      function Control_Only return Boolean is
      begin
         return Modifiers (Files.Types.Control_Key)
           and then not Modifiers (Files.Types.Shift_Key)
           and then not Modifiers (Files.Types.Alt_Key)
           and then not Modifiers (Files.Types.Meta_Key);
      end Control_Only;
   begin
      if Files.Model.Command_Palette_Is_Open (Model) then
         if Key = Files.Types.Key_Escape and then Modifiers = Files.Types.No_Modifiers then
            Files.Model.Close_Command_Palette (Model);
            return Make_Result (Controller_Palette_Updated, Files.Commands.Close_Command_Palette_Command);
         elsif Key = Files.Types.Key_Return and then Modifiers = Files.Types.No_Modifiers then
            return Commit_Focused_Text (Model, Settings, Modifiers);
         elsif Key = Files.Types.Key_Left and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Move_Palette_Selection (Model, Files.Types.Move_Left);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_Right and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Move_Palette_Selection (Model, Files.Types.Move_Right);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_Up and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Move_Palette_Selection (Model, Files.Types.Move_Up);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_Down and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Move_Palette_Selection (Model, Files.Types.Move_Down);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_Home and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Jump_Palette_Selection (Model, Last => False);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_End and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Jump_Palette_Selection (Model, Last => True);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_Page_Up and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Page_Palette_Selection (Model, Down => False);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         elsif Key = Files.Types.Key_Page_Down and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Index  : constant Natural := Files.Model.Command_Palette_Selected_Index (Model);
               Old_Offset : constant Natural := Files.Model.Command_Palette_Result_Offset (Model);
            begin
               Page_Palette_Selection (Model, Down => True);
               return Palette_Selection_Result (Model, Old_Index, Old_Offset);
            end;
         end if;
      end if;

      if Files.Model.Root_Selector_Is_Open (Model) then
         if Key = Files.Types.Key_Escape and then Modifiers = Files.Types.No_Modifiers then
            Files.Model.Close_Root_Selector (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Files.Types.Key_Return and then Modifiers = Files.Types.No_Modifiers then
            return Handle_Root_Click (Model, Settings, Files.Model.Root_Selected_Index (Model));
         elsif Key = Files.Types.Key_Left and then Modifiers = Files.Types.No_Modifiers then
            return Root_Selection_Result (Model, Files.Types.Move_Left);
         elsif Key = Files.Types.Key_Right and then Modifiers = Files.Types.No_Modifiers then
            return Root_Selection_Result (Model, Files.Types.Move_Right);
         elsif Key = Files.Types.Key_Up and then Modifiers = Files.Types.No_Modifiers then
            return Root_Selection_Result (Model, Files.Types.Move_Up);
         elsif Key = Files.Types.Key_Down and then Modifiers = Files.Types.No_Modifiers then
            return Root_Selection_Result (Model, Files.Types.Move_Down);
         elsif Key = Files.Types.Key_Home and then Modifiers = Files.Types.No_Modifiers then
            return Root_Jump_Result (Model, 1);
         elsif Key = Files.Types.Key_End and then Modifiers = Files.Types.No_Modifiers then
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
         if Key = Files.Types.Key_Escape and then Modifiers = Files.Types.No_Modifiers then
            Files.Model.Toggle_Settings_Pane (Model);
            return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);
         elsif Key = Files.Types.Key_Up and then Modifiers = Files.Types.No_Modifiers then
            Files.Model.Move_Settings_Field (Model, Files.Types.Move_Up);
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif Key = Files.Types.Key_Down and then Modifiers = Files.Types.No_Modifiers then
            Files.Model.Move_Settings_Field (Model, Files.Types.Move_Down);
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         elsif Key = Files.Types.Key_N and then Modifiers (Files.Types.Control_Key) then
            declare
               Old_Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
               Old_Field  : constant Natural := Files.Model.Settings_Field_Index (Model);
               Old_Text   : constant String := Files.Model.Settings_Field_Text (Model);
               Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
            begin
               Files.Model.Add_Settings_Entry (Model);
               return Settings_Update_Result (Model, Old_Draft, Old_Field, Old_Text, Old_Cursor);
            end;
         elsif Key = Files.Types.Key_Delete and then Modifiers (Files.Types.Control_Key) then
            declare
               Old_Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
               Old_Field  : constant Natural := Files.Model.Settings_Field_Index (Model);
               Old_Text   : constant String := Files.Model.Settings_Field_Text (Model);
               Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
            begin
               Files.Model.Remove_Settings_Entry (Model);
               return Settings_Update_Result (Model, Old_Draft, Old_Field, Old_Text, Old_Cursor);
            end;
         elsif Key = Files.Types.Key_Page_Up and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
               Old_Field  : constant Natural := Files.Model.Settings_Field_Index (Model);
               Old_Text   : constant String := Files.Model.Settings_Field_Text (Model);
               Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
            begin
               Files.Model.Move_Settings_Entry (Model, Files.Types.Move_Up);
               return Settings_Update_Result (Model, Old_Draft, Old_Field, Old_Text, Old_Cursor);
            end;
         elsif Key = Files.Types.Key_Page_Down and then Modifiers = Files.Types.No_Modifiers then
            declare
               Old_Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
               Old_Field  : constant Natural := Files.Model.Settings_Field_Index (Model);
               Old_Text   : constant String := Files.Model.Settings_Field_Text (Model);
               Old_Cursor : constant Natural := Files.Model.Text_Cursor_Position (Model);
            begin
               Files.Model.Move_Settings_Entry (Model, Files.Types.Move_Down);
               return Settings_Update_Result (Model, Old_Draft, Old_Field, Old_Text, Old_Cursor);
            end;
         elsif (Key = Files.Types.Key_Left or else Key = Files.Types.Key_Right
                or else Key = Files.Types.Key_Space)
           and then Modifiers = Files.Types.No_Modifiers
           and then Files.Model.Settings_Field_Index (Model) <= 7
         then
            declare
               Min_Font_Pixel_Size : constant := 10;
               Max_Font_Pixel_Size : constant := 32;

               Field   : constant Natural := Files.Model.Settings_Field_Index (Model);
               Current : constant String := Files.Types.To_Lower (Files.Model.Settings_Field_Text (Model));
               Forward : constant Boolean := Key /= Files.Types.Key_Left;
               Touched : Boolean := False;
            begin
               --  Space cycles fields that have inline toggle/segmented
               --  controls (default_view + boolean fields). On other
               --  multi-choice fields it falls through to text input.
               if Key = Files.Types.Key_Space
                 and then Field not in 1 | 2 | 4 | 5
               then
                  return Make_Result (Controller_Ignored);
               end if;

               case Field is
                  when 1 =>
                     if Current = "small_icons" or else Current = "small" then
                        Files.Model.Set_Settings_Field_Text
                          (Model, (if Forward then "large_icons" else "details"));
                     elsif Current = "large_icons" or else Current = "large" then
                        Files.Model.Set_Settings_Field_Text
                          (Model, (if Forward then "details" else "small_icons"));
                     else
                        Files.Model.Set_Settings_Field_Text
                          (Model, (if Forward then "small_icons" else "large_icons"));
                     end if;
                     Touched := True;
                  when 2 | 4 =>
                     Files.Model.Set_Settings_Field_Text
                       (Model, (if Current = "true" then "false" else "true"));
                     Touched := True;
                  when 5 =>
                     if Current = "dark" then
                        Files.Model.Set_Settings_Field_Text
                          (Model, (if Forward then "light" else "high_contrast"));
                     elsif Current = "light" then
                        Files.Model.Set_Settings_Field_Text
                          (Model, (if Forward then "high_contrast" else "dark"));
                     else
                        Files.Model.Set_Settings_Field_Text
                          (Model, (if Forward then "dark" else "light"));
                     end if;
                     Touched := True;
                  when 6 =>
                     Files.Model.Set_Settings_Field_Text
                       (Model,
                        (if Current = "files-basic" then "files-high-contrast" else "files-basic"));
                     Touched := True;
                  when 3 =>
                     if Current = "name" then
                        Files.Model.Set_Settings_Field_Text (Model, (if Forward then "filetype" else "modified"));
                     elsif Current = "filetype" then
                        Files.Model.Set_Settings_Field_Text (Model, (if Forward then "size" else "name"));
                     elsif Current = "size" then
                        Files.Model.Set_Settings_Field_Text (Model, (if Forward then "created" else "filetype"));
                     elsif Current = "created" then
                        Files.Model.Set_Settings_Field_Text (Model, (if Forward then "modified" else "size"));
                     else
                        Files.Model.Set_Settings_Field_Text (Model, (if Forward then "name" else "created"));
                     end if;
                     Touched := True;
                  when 7 =>
                     declare
                        Step    : constant Integer := (if Forward then 1 else -1);
                        Current_N : Integer := 0;
                        Next_N    : Integer;
                     begin
                        begin
                           Current_N := Integer'Value (Files.Model.Settings_Field_Text (Model));
                        exception
                           when Constraint_Error =>
                              Current_N := 16;
                        end;
                        Next_N := Current_N + Step;
                        if Next_N < Min_Font_Pixel_Size then
                           Next_N := Min_Font_Pixel_Size;
                        elsif Next_N > Max_Font_Pixel_Size then
                           Next_N := Max_Font_Pixel_Size;
                        end if;
                        if Next_N /= Current_N then
                           Files.Model.Set_Settings_Field_Text
                             (Model, Ada.Strings.Fixed.Trim
                                (Integer'Image (Next_N), Ada.Strings.Both));
                           Touched := True;
                        else
                           --  Font-size stepper at its min/max bound: nothing
                           --  changed, so report nothing rather than a spurious
                           --  update.
                           return Make_Result (Controller_Ignored);
                        end if;
                     end;
                  when others =>
                     null;
               end case;

               if Touched then
                  return Make_Result
                    (Controller_Command_Executed, Files.Commands.Save_Settings_Command);
               end if;
            end;
            return Make_Result (Controller_Text_Updated, Files.Commands.Toggle_Settings_Pane_Command);
         end if;
      end if;

      if Key = Files.Types.Key_Return then
         if Modifiers = Files.Types.No_Modifiers then
            return Commit_Focused_Text (Model, Settings, Modifiers);
         elsif Files.Model.Focus (Model) = Files.Types.Focus_None then
            return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);
         end if;
      elsif Key = Files.Types.Key_Backspace
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Word_Backward (Model);
      elsif Key = Files.Types.Key_Delete
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Word_Forward (Model);
      elsif Key = Files.Types.Key_Left
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets_Word (Model, Files.Types.Move_Left)
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
      elsif Key = Files.Types.Key_Right
        and then Control_Only
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets_Word (Model, Files.Types.Move_Right)
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
      elsif Key = Files.Types.Key_Backspace
        and then Modifiers = Files.Types.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Backward (Model);
      elsif Key = Files.Types.Key_Delete
        and then Modifiers = Files.Types.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
      then
         return Delete_Focused_Text_Forward (Model);
      elsif Key = Files.Types.Key_Left
        and then Modifiers = Files.Types.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets (Model, Files.Types.Move_Left)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Move_Text_Cursor (Model, Files.Types.Move_Left);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Files.Types.Key_Right
        and then Modifiers = Files.Types.No_Modifiers
        and then Files.Model.Focus (Model) /= Files.Types.Focus_None
        and then Files.Model.Focus (Model) /= Files.Types.Focus_Command_Palette
      then
         declare
            Old_Position : constant Natural := Files.Model.Text_Cursor_Position (Model);
         begin
            if Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input then
               return
                 Make_Result
                   (if Files.Model.Rename_Move_All_Carets (Model, Files.Types.Move_Right)
                    then Controller_Text_Updated
                    else Controller_Ignored);
            end if;
            Files.Model.Move_Text_Cursor (Model, Files.Types.Move_Right);
            return
              Make_Result
                (if Files.Model.Text_Cursor_Position (Model) = Old_Position
                 then Controller_Ignored
                 else Controller_Text_Updated);
         end;
      elsif Key = Files.Types.Key_Home
        and then Modifiers = Files.Types.No_Modifiers
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
      elsif Key = Files.Types.Key_End
        and then Modifiers = Files.Types.No_Modifiers
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
      elsif Key = Files.Types.Key_Page_Up
        and then Modifiers = Files.Types.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         if Files.Model.Info_Pane_Is_Open (Model) then
            return Scroll_Info_Result (Model, -10);
         else
            return Scroll_Main_Result (Model, -10);
         end if;
      elsif Key = Files.Types.Key_Page_Down
        and then Modifiers = Files.Types.No_Modifiers
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
        and then not Files.Model.Settings_Pane_Is_Open (Model)
      then
         if Files.Model.Info_Pane_Is_Open (Model) then
            return Scroll_Info_Result (Model, 10);
         else
            return Scroll_Main_Result (Model, 10);
         end if;
      elsif Key = Files.Types.Key_Escape and then Modifiers = Files.Types.No_Modifiers then
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
            | Files.Events.Tree_Click_Input_Action
            | Files.Events.Command_Result_Click_Input_Action
            | Files.Events.Scrollbar_Drag_Begin_Input_Action
            | Files.Events.Column_Resize_Begin_Input_Action =>
            null;
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Key;

end Files.Controller;
