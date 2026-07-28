with Files.Model.Support;
with Files.UTF8;

package body Files.Model.Rename is
   use Files.Model.Support;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.Focus_Target;
   use Ada.Strings.Unbounded;

   procedure Focus_Rename_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Rename_Active then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Rename_Input;
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      end if;
   end Focus_Rename_Input;

   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean is
   begin
      return Selected_Count (Model) >= 1 and then not Selection_Includes_Temporary (Model);
   end Rename_Is_Enabled;

   function Rename_Behavior return Rename_Policy is
   begin
      return
        (Single_Item_Only       => False,
         Synchronized_Multi     => True,
         Atomic_Multi_Rename    => False,
         Requires_One_Selection => False);
   end Rename_Behavior;

   procedure Toggle_Rename
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Rename_Active then
         if Is_Temporary_Rename (Model) then
            Cancel_Create_File (Model);
            if Model.Focus_Value = Files.Types.Focus_Rename_Input then
               Model.Focus_Value := Files.Types.Focus_None;
            end if;
            return;
         end if;

         Reset_Rename_State (Model);
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      elsif Rename_Is_Enabled (Model) then
         Clear_Overlay_State_For_Edit (Model);
         Model.Rename_Fields.Clear;
         declare
            Indexes : constant Natural_Vectors.Vector := Selected_Loaded_Indexes (Model);
         begin
            for Item_Index of Indexes loop
               declare
                  Name : constant String :=
                    To_String (Model.Items.Element (Positive (Item_Index)).Name);
               begin
                  Model.Rename_Fields.Append
                    (Rename_Field'
                       (Item_Index => Item_Index,
                        Value      => To_Unbounded_String (Name),
                        Cursor     => Caret_Before_Extension (Name)));
               end;
            end loop;
         end;

         if not Model.Rename_Fields.Is_Empty then
            Model.Rename_Active := True;
            Model.Focus_Value := Files.Types.Focus_Rename_Input;
         end if;
      end if;
   end Toggle_Rename;

   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Rename_Active;
   end Rename_Is_Active;

   function Rename_Field_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Rename_Fields.Length);
   end Rename_Field_Count;

   function Rename_Text
     (Model : Window_Model)
      return String is
   begin
      return First_Rename_Value (Model);
   end Rename_Text;

   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Rename_Active and then not Model.Rename_Fields.Is_Empty then
         declare
            Field : Rename_Field := Model.Rename_Fields.First_Element;
         begin
            Field.Value := To_Unbounded_String (Text);
            Field.Cursor := Text'Length;
            Model.Rename_Fields.Replace_Element (Model.Rename_Fields.First_Index, Field);
            Sync_Temporary_From_Field (Model, Field);
         end;
      end if;
   end Set_Rename_Text;

   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Text = "" then
         return False;
      end if;

      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Old   : constant String := To_String (Field.Value);
            Base  : constant Natural := Natural'Min (Field.Cursor, Old'Length);
         begin
            Field.Value := To_Unbounded_String (Insert_Text_At (Old, Base, Text));
            Field.Cursor := Base + Text'Length;
            Model.Rename_Fields.Replace_Element (Index, Field);
            Sync_Temporary_From_Field (Model, Field);
            Changed := True;
         end;
      end loop;

      return Changed;
   end Rename_Insert_At_Carets;

   function Rename_Delete_Backward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Text  : constant String := To_String (Field.Value);
         begin
            if Field.Cursor > 0 and then Text'Length > 0 then
               declare
                  Previous : constant Natural := Files.UTF8.Previous_Boundary (Text, Field.Cursor);
               begin
                  Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Previous, Field.Cursor));
                  Field.Cursor := Previous;
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Backward;

   function Rename_Delete_Forward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Text  : constant String := To_String (Field.Value);
         begin
            if Field.Cursor < Text'Length then
               declare
                  Next : constant Natural := Files.UTF8.Next_Boundary (Text, Field.Cursor);
               begin
                  Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Field.Cursor, Next));
                  Model.Rename_Fields.Replace_Element (Index, Field);
                  Sync_Temporary_From_Field (Model, Field);
                  Changed := True;
               end;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Forward;

   function Rename_Delete_Word_Backward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field    : Rename_Field := Model.Rename_Fields.Element (Index);
            Text     : constant String := To_String (Field.Value);
            Boundary : constant Natural := Files.UTF8.Previous_Word_Boundary (Text, Field.Cursor);
         begin
            if Field.Cursor > 0 and then Boundary < Field.Cursor then
               Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Boundary, Field.Cursor));
               Field.Cursor := Boundary;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Sync_Temporary_From_Field (Model, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Word_Backward;

   function Rename_Delete_Word_Forward
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field    : Rename_Field := Model.Rename_Fields.Element (Index);
            Text     : constant String := To_String (Field.Value);
            Boundary : constant Natural := Files.UTF8.Next_Word_Boundary (Text, Field.Cursor);
         begin
            if Field.Cursor < Text'Length and then Boundary > Field.Cursor then
               Field.Value := To_Unbounded_String (Files.UTF8.Remove_Range (Text, Field.Cursor, Boundary));
               Model.Rename_Fields.Replace_Element (Index, Field);
               Sync_Temporary_From_Field (Model, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Delete_Word_Forward;

   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is
      Backward : constant Boolean :=
        Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
      Changed  : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename_Fields.Element (Index);
            Text       : constant String := To_String (Field.Value);
            New_Cursor : Natural := Field.Cursor;
         begin
            if Backward then
               if Field.Cursor > 0 then
                  New_Cursor := Files.UTF8.Previous_Boundary (Text, Field.Cursor);
               end if;
            elsif Field.Cursor < Text'Length then
               New_Cursor := Files.UTF8.Next_Boundary (Text, Field.Cursor);
            end if;

            if New_Cursor /= Field.Cursor then
               Field.Cursor := New_Cursor;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Move_All_Carets;

   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean
   is
      Backward : constant Boolean :=
        Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
      Changed  : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename_Fields.Element (Index);
            Text       : constant String := To_String (Field.Value);
            New_Cursor : constant Natural :=
              (if Backward then Files.UTF8.Previous_Word_Boundary (Text, Field.Cursor)
               else Files.UTF8.Next_Word_Boundary (Text, Field.Cursor));
         begin
            if New_Cursor /= Field.Cursor then
               Field.Cursor := New_Cursor;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Move_All_Carets_Word;

   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
         begin
            if Field.Cursor /= 0 then
               Field.Cursor := 0;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Set_All_Carets_Home;

   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Index in Model.Rename_Fields.First_Index .. Model.Rename_Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename_Fields.Element (Index);
            Last  : constant Natural := Length (Field.Value);
         begin
            if Field.Cursor /= Last then
               Field.Cursor := Last;
               Model.Rename_Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      return Changed;
   end Rename_Set_All_Carets_End;

   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Visible_Index = 0 or else not Model.Rename_Active then
         return;
      end if;

      declare
         Field_Index : constant Natural := Find_Rename_Field (Model, Positive (Visible_Index));
      begin
         if Field_Index /= 0 then
            declare
               Field : Rename_Field := Model.Rename_Fields.Element (Field_Index);
            begin
               Field.Cursor := Files.UTF8.Boundary_At_Or_Before (To_String (Field.Value), Position);
               Model.Rename_Fields.Replace_Element (Field_Index, Field);
            end;
         end if;
      end;
   end Set_Rename_Caret;

   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
   is
      Field_Index : constant Natural :=
        (if Model.Rename_Active then Find_Rename_Field (Model, Visible_Index) else 0);
   begin
      if Field_Index = 0 then
         Active := False;
         Value  := Null_Unbounded_String;
         Cursor := 0;
      else
         declare
            Field : constant Rename_Field := Model.Rename_Fields.Element (Field_Index);
         begin
            Active := True;
            Value  := Field.Value;
            Cursor := Field.Cursor;
         end;
      end if;
   end Rename_State_For_Visible;

   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector
   is
      Result : Rename_Target_Vectors.Vector;
   begin
      for Field of Model.Rename_Fields loop
         if Field.Item_Index in 1 .. Natural (Model.Items.Last_Index) then
            declare
               Item : constant Files.File_System.Directory_Item :=
                 Model.Items.Element (Positive (Field.Item_Index));
            begin
               Result.Append
                 (Rename_Target'
                    (Item_Index    => Field.Item_Index,
                     Old_Full_Path => Item.Full_Path,
                     Old_Name      => Item.Name,
                     New_Name      => Field.Value));
            end;
         end if;
      end loop;

      return Result;
   end Rename_Targets;

   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if not Rename_Is_Enabled (Model) then
         return;
      end if;

      Clear_Overlay_State_For_Edit (Model);
      Model.Rename_Fields.Clear;
      Model.Rename_Fields.Append
        (Rename_Field'
           (Item_Index => Effective_Selected_Item_Index (Model),
            Value      => To_Unbounded_String (Text),
            Cursor     => Text'Length));
      Model.Rename_Active := True;
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
   end Resume_Rename;

end Files.Model.Rename;
