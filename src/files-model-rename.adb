with Guikit.Utf8.Editing;
with Files.Model.Support;

package body Files.Model.Rename is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Navigation_Direction;

   --  Return the first rename field's text, or an empty string when inactive.
   --
   --  @param Model Model to inspect.
   --  @return The active rename text, or "" when no rename is active.
   function First_Rename_Value
     (Model : Window_Model)
      return String is
   begin
      if Model.Rename.Fields.Is_Empty then
         return "";
      else
         return To_String (Model.Rename.Fields.First_Element.Edit.Text);
      end if;
   end First_Rename_Value;

   --  Insert Text into Old at the byte offset Cursor (clamped into range).
   --
   --  @param Old Existing text.
   --  @param Cursor Byte offset to insert at.
   --  @param Text Text to insert.
   --  @return Old with Text spliced in at Cursor.
   function Insert_Text_At
     (Old    : String;
      Cursor : Natural;
      Text   : String)
      return String is
   begin
      if Cursor = 0 then
         return Text & Old;
      elsif Cursor >= Old'Length then
         return Old & Text;
      else
         return Old (Old'First .. Old'First + Cursor - 1)
           & Text
           & Old (Old'First + Cursor .. Old'Last);
      end if;
   end Insert_Text_At;

   --  Return the byte offset before a name's extension: the position of the
   --  last non-leading dot, or the name length when there is no extension.
   --
   --  @param Name File name.
   --  @return Byte offset before the extension (name-relative).
   function Caret_Before_Extension
     (Name : String)
      return Natural
   is
      Start : constant Natural := Files.Types.Extension_Start (Name);
      Dot   : constant Natural := (if Start = 0 then 0 else Start - Name'First);
   begin
      if Dot = 0 then
         return Name'Length;
      else
         return Guikit.Utf8.Editing.Boundary_At_Or_Before (Name, Dot);
      end if;
   end Caret_Before_Extension;

   --  Return the loaded-item indexes of the current real (non-temporary)
   --  selection, in loaded order, for populating rename fields.
   --
   --  @param Model Model to inspect.
   --  @return Loaded-item indexes of the real selection.
   function Selected_Loaded_Indexes
     (Model : Window_Model)
      return Natural_Vectors.Vector
   is
      Result : Natural_Vectors.Vector;
   begin
      if Model.Items.Is_Empty then
         return Result;
      end if;

      declare
         Selected : constant Selection_Flags := Selected_Flags (Model);
      begin
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Selected (Index)
              and then Item_Is_Visible (Model, Model.Items (Index))
            then
               Result.Append (Natural (Index));
            end if;
         end loop;
      end;

      return Result;
   end Selected_Loaded_Indexes;

   --  Update the temporary-item name buffer to track its rename field's value.
   --
   --  @param Model Model to update.
   --  @param Field The temporary item's rename field.
   procedure Sync_Temporary_From_Field
     (Model : in out Window_Model;
      Field : Rename_Field) is
   begin
      Touch (Model);
      if Field.Item_Index = 0 and then Model.Temporary.Active then
         Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
         Model.Temporary.Name := Field.Edit.Text;
      end if;
   end Sync_Temporary_From_Field;

   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean is
     (Selected_Count (Model) >= 1 and then not Selection_Includes_Temporary (Model));

   procedure Toggle_Rename
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      if Model.Rename.Active then
         if Is_Temporary_Rename (Model) then
            --  Which also takes the focus from the rename field.
            Cancel_Create_File (Model);
            return;
         end if;

         Reset_Rename_State (Model);
         if Model.Focus_Value = Files.Types.Focus_Rename_Input then
            Model.Focus_Value := Files.Types.Focus_None;
         end if;
      elsif Rename_Is_Enabled (Model) then
         Clear_Overlay_State_For_Edit (Model);
         Model.Rename.Fields.Clear;
         declare
            Indexes : constant Natural_Vectors.Vector := Selected_Loaded_Indexes (Model);
         begin
            for Item_Index of Indexes loop
               declare
                  Name : constant String :=
                    To_String (Model.Items.Element (Item_Index).Name);
               begin
                  Model.Rename.Fields.Append
                    (Rename_Field'
                       (Item_Index => Item_Index,
                        Edit       => (Text => To_Unbounded_String (Name), Cursor => Caret_Before_Extension (Name))));
               end;
            end loop;
         end;

         if not Model.Rename.Fields.Is_Empty then
            Model.Rename.Active := True;
            Model.Focus_Value := Files.Types.Focus_Rename_Input;
         end if;
      end if;
   end Toggle_Rename;

   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Rename.Active);

   function Rename_Text
     (Model : Window_Model)
      return String is
     (First_Rename_Value (Model));

   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      if Model.Rename.Active and then not Model.Rename.Fields.Is_Empty then
         declare
            Field : Rename_Field := Model.Rename.Fields.First_Element;
         begin
            Field.Edit.Text := To_Unbounded_String (Text);
            Field.Edit.Cursor := Text'Length;
            Model.Rename.Fields.Replace_Element (Model.Rename.Fields.First_Index, Field);
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
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      if Text = "" then
         return False;
      end if;

      for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename.Fields.Element (Index);
            Old   : constant String := To_String (Field.Edit.Text);
            Base  : constant Natural := Natural'Min (Field.Edit.Cursor, Old'Length);
         begin
            Field.Edit.Text := To_Unbounded_String (Insert_Text_At (Old, Base, Text));
            Field.Edit.Cursor := Base + Text'Length;
            Model.Rename.Fields.Replace_Element (Index, Field);
            Sync_Temporary_From_Field (Model, Field);
            Changed := True;
         end;
      end loop;

      return Changed;
   end Rename_Insert_At_Carets;

   function Rename_Delete
     (Model    : in out Window_Model;
      Backward : Boolean;
      By_Word  : Boolean := False)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename.Fields.Element (Index);
            Text       : constant String := To_String (Field.Edit.Text);
            New_Text   : Unbounded_String;
            New_Cursor : Natural;
         begin
            Guikit.Utf8.Editing.Delete_At (Text, Field.Edit.Cursor, Backward, By_Word, New_Text, New_Cursor);
            if Length (New_Text) /= Text'Length then
               Field.Edit.Text := New_Text;
               Field.Edit.Cursor := New_Cursor;
               Model.Rename.Fields.Replace_Element (Index, Field);
               Sync_Temporary_From_Field (Model, Field);
               Changed := True;
            end if;
         end;
      end loop;

      --  A key that deleted nothing changes nothing to redraw.
      if Changed then
         Touch (Model);
         Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      end if;
      return Changed;
   end Rename_Delete;

   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction;
      By_Word   : Boolean := False)
      return Boolean
   is
      Backward : constant Boolean :=
        Direction = Guikit.Input.Move_Left or else Direction = Guikit.Input.Move_Up;
      Changed  : Boolean := False;
   begin
      for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
         declare
            Field      : Rename_Field := Model.Rename.Fields.Element (Index);
            Text       : constant String := To_String (Field.Edit.Text);
            New_Cursor : Natural := Field.Edit.Cursor;
         begin
            if By_Word then
               New_Cursor :=
                 (if Backward then Guikit.Utf8.Editing.Previous_Word_Boundary (Text, Field.Edit.Cursor)
                  else Guikit.Utf8.Editing.Next_Word_Boundary (Text, Field.Edit.Cursor));
            elsif Backward then
               if Field.Edit.Cursor > 0 then
                  New_Cursor := Guikit.Utf8.Editing.Previous_Boundary (Text, Field.Edit.Cursor);
               end if;
            elsif Field.Edit.Cursor < Text'Length then
               New_Cursor := Guikit.Utf8.Editing.Next_Boundary (Text, Field.Edit.Cursor);
            end if;

            if New_Cursor /= Field.Edit.Cursor then
               Field.Edit.Cursor := New_Cursor;
               Model.Rename.Fields.Replace_Element (Index, Field);
               Changed := True;
            end if;
         end;
      end loop;

      --  A key that moved no caret changes nothing to redraw.
      if Changed then
         Touch (Model);
      end if;
      return Changed;
   end Rename_Move_All_Carets;

   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean
   is
      Changed : Boolean := False;
   begin
      Touch (Model);
      for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename.Fields.Element (Index);
         begin
            if Field.Edit.Cursor /= 0 then
               Field.Edit.Cursor := 0;
               Model.Rename.Fields.Replace_Element (Index, Field);
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
      Touch (Model);
      for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
         declare
            Field : Rename_Field := Model.Rename.Fields.Element (Index);
            Last  : constant Natural := Length (Field.Edit.Text);
         begin
            if Field.Edit.Cursor /= Last then
               Field.Edit.Cursor := Last;
               Model.Rename.Fields.Replace_Element (Index, Field);
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
      Touch (Model);
      if Visible_Index = 0 or else not Model.Rename.Active then
         return;
      end if;

      declare
         Field_Index : constant Natural := Find_Rename_Field (Model, Positive (Visible_Index));
      begin
         if Field_Index /= 0 then
            declare
               Field : Rename_Field := Model.Rename.Fields.Element (Field_Index);
            begin
               Field.Edit.Cursor := Guikit.Utf8.Editing.Boundary_At_Or_Before (To_String (Field.Edit.Text), Position);
               Model.Rename.Fields.Replace_Element (Field_Index, Field);
            end;
         end if;
      end;
   end Set_Rename_Caret;

   procedure For_Each_Rename_Field
     (Model : Window_Model;
      Visit : not null access procedure (Item_Index : Natural; Value : UString; Cursor : Natural)) is
   begin
      if Model.Rename.Active then
         for Field of Model.Rename.Fields loop
            Visit (Field.Item_Index, Field.Edit.Text, Field.Edit.Cursor);
         end loop;
      end if;
   end For_Each_Rename_Field;

   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector
   is
      Result : Rename_Target_Vectors.Vector;
   begin
      for Field of Model.Rename.Fields loop
         if Field.Item_Index in 1 .. Natural (Model.Items.Last_Index) then
            declare
               Item : constant Files.Items.Directory_Item :=
                 Model.Items.Element (Positive (Field.Item_Index));
            begin
               Result.Append
                 (Rename_Target'
                    (Item_Index    => Field.Item_Index,
                     Old_Full_Path => Item.Full_Path,
                     Old_Name      => Item.Name,
                     New_Name      => Field.Edit.Text));
            end;
         end if;
      end loop;

      return Result;
   end Rename_Targets;

   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Touch (Model);
      Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
      if not Rename_Is_Enabled (Model) then
         return;
      end if;

      Clear_Overlay_State_For_Edit (Model);
      Model.Rename.Fields.Clear;
      Model.Rename.Fields.Append
        (Rename_Field'
           (Item_Index => Effective_Selected_Item_Index (Model),
            Edit       => (Text => To_Unbounded_String (Text), Cursor => Text'Length)));
      Model.Rename.Active := True;
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
   end Resume_Rename;

end Files.Model.Rename;
