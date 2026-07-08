with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.Localization;
with Files.Settings;
with Files.Types;

package body Files.Settings_Form is

   use Ada.Strings.Unbounded;
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;
   package SP renames Guikit.Settings_Panel;
   use type SP.Change_Kind;

   function U (S : String) return Unbounded_String renames To_Unbounded_String;
   function L (Key : String) return Unbounded_String is (U (Files.Localization.Text (Key)));
   function Img (N : Natural) return String is (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Both));

   --  Small option-vector builders (tokens and localized labels).
   function V2 (A, B : String) return SP.UString_Vectors.Vector is
      R : SP.UString_Vectors.Vector;
   begin
      R.Append (U (A));
      R.Append (U (B));
      return R;
   end V2;

   function LV2 (A, B : String) return SP.UString_Vectors.Vector is
      R : SP.UString_Vectors.Vector;
   begin
      R.Append (L (A));
      R.Append (L (B));
      return R;
   end LV2;

   function V3 (A, B, C : String) return SP.UString_Vectors.Vector is
      R : SP.UString_Vectors.Vector;
   begin
      R.Append (U (A));
      R.Append (U (B));
      R.Append (U (C));
      return R;
   end V3;

   function LV3 (A, B, C : String) return SP.UString_Vectors.Vector is
      R : SP.UString_Vectors.Vector;
   begin
      R.Append (L (A));
      R.Append (L (B));
      R.Append (L (C));
      return R;
   end LV3;

   function V5 (A, B, C, D, E : String) return SP.UString_Vectors.Vector is
      R : SP.UString_Vectors.Vector;
   begin
      R.Append (U (A));
      R.Append (U (B));
      R.Append (U (C));
      R.Append (U (D));
      R.Append (U (E));
      return R;
   end V5;

   function LV5 (A, B, C, D, E : String) return SP.UString_Vectors.Vector is
      R : SP.UString_Vectors.Vector;
   begin
      R.Append (L (A));
      R.Append (L (B));
      R.Append (L (C));
      R.Append (L (D));
      R.Append (L (E));
      return R;
   end LV5;

   function Fields
     (Model : Files.Model.Window_Model)
      return SP.Field_Vectors.Vector
   is
      D      : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      Result : SP.Field_Vectors.Vector;

      procedure Section (Key : String) is
      begin
         Result.Append (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Section, others => <>));
      end Section;

      procedure Toggle (Key : String; Value : UString) is
      begin
         Result.Append
           (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Toggle, Value => Value, others => <>));
      end Toggle;

      procedure Choice (Key : String; Value : UString; Toks, Labels : SP.UString_Vectors.Vector) is
      begin
         Result.Append
           (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Choice, Value => Value,
                      Option_Values => Toks, Option_Labels => Labels, others => <>));
      end Choice;

      procedure Number_Field (Key : String; Value : UString; Min, Max : Integer) is
      begin
         Result.Append
           (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Number, Value => Value,
                      Min => Min, Max => Max, others => <>));
      end Number_Field;

      --  A key/value mapping group: a Prev/Add/Remove/Next button row followed by
      --  the selected entry's key and value text fields. The key field's label
      --  carries an "i/n" counter so the user can see which entry they are on
      --  while paging through the list with Prev/Next.
      procedure Mapping_Group
        (Buttons_Key : String;
         Key_Key     : String;
         Key_Value   : UString;
         Val_Key     : String;
         Val_Value   : UString;
         Index       : Natural;
         Count       : Natural)
      is
         Nav_Toks, Nav_Labels : SP.UString_Vectors.Vector;
         Key_Label : constant UString :=
           (if Count > 0
            then L (Key_Key) & U (" (" & Img (Index) & "/" & Img (Count) & ")")
            else L (Key_Key));
      begin
         Nav_Toks.Append (U ("prev"));
         Nav_Toks.Append (U ("add"));
         Nav_Toks.Append (U ("remove"));
         Nav_Toks.Append (U ("next"));
         Nav_Labels.Append (L ("settings.previous"));
         Nav_Labels.Append (L ("settings.add"));
         Nav_Labels.Append (L ("settings.remove"));
         Nav_Labels.Append (L ("settings.next"));
         Result.Append
           (SP.Field'(Key => U (Buttons_Key), Label => Null_Unbounded_String, Kind => SP.Buttons,
                      Option_Values => Nav_Toks, Option_Labels => Nav_Labels, others => <>));
         Result.Append
           (SP.Field'(Key => U (Key_Key), Label => Key_Label, Kind => SP.Text, Value => Key_Value, others => <>));
         Result.Append
           (SP.Field'(Key => U (Val_Key), Label => L (Val_Key), Kind => SP.Text, Value => Val_Value, others => <>));
      end Mapping_Group;

      procedure Action_Buttons is
         Toks, Labels : SP.UString_Vectors.Vector;
      begin
         Toks.Append (U ("reset"));
         Labels.Append (L ("settings.reset"));
         Result.Append
           (SP.Field'(Key => U ("settings.actions"), Label => Null_Unbounded_String,
                      Kind => SP.Buttons, Option_Values => Toks, Option_Labels => Labels, others => <>));
      end Action_Buttons;
   begin
      Action_Buttons;
      Section ("settings.section.view");
      Choice ("settings.view", D.Default_View_Mode,
              V3 ("small_icons", "large_icons", "details"),
              LV3 ("command.view.small", "command.view.large", "command.view.details"));
      Toggle ("settings.hidden_files", D.Show_Hidden_Files);

      Section ("settings.section.sorting");
      Choice ("settings.sort", D.Sort_Field_Value,
              V5 ("name", "filetype", "size", "created", "modified"),
              LV5 ("settings.sort.name", "settings.sort.filetype", "settings.sort.size",
                   "settings.sort.created", "settings.sort.modified"));
      Toggle ("settings.sort_ascending", D.Sort_Ascending);

      Section ("settings.section.appearance");
      Choice ("settings.theme", D.Theme,
              V3 ("dark", "light", "high_contrast"),
              LV3 ("settings.theme.dark", "settings.theme.light", "settings.theme.high_contrast"));
      Choice ("settings.icon_theme", D.Icon_Theme_Name,
              V2 ("files-basic", "files-high-contrast"),
              LV2 ("settings.icon_theme.basic", "settings.icon_theme.high_contrast"));
      Number_Field ("settings.font_pixel_size", D.Font_Pixel_Size, 10, 32);

      Section ("settings.section.behavior");
      Toggle ("settings.system_opener", D.Use_System_Default_Opener);

      Section ("settings.section.details");
      Choice ("settings.grouping", D.Group_By,
              V5 ("none", "type", "modified", "size", "label"),
              LV5 ("settings.group.none", "settings.group.type", "settings.group.modified",
                   "settings.group.size", "settings.group.label"));
      Toggle ("settings.column.modified", D.Column_Modified);
      Toggle ("settings.column.size", D.Column_Size);
      Toggle ("settings.column.type", D.Column_Filetype);
      Toggle ("settings.column.created", D.Column_Created);
      Toggle ("settings.column.permissions", D.Column_Permissions);

      Section ("settings.section.file_types");
      Mapping_Group ("settings.filetype.buttons",
                     "settings.filetype_extension", D.Filetype_Extension,
                     "settings.filetype_value", D.Filetype_Value,
                     D.Filetype_Index, Natural (D.Filetype_Keys.Length));
      Mapping_Group ("settings.icon.buttons",
                     "settings.icon_filetype", D.Icon_Filetype,
                     "settings.icon_value", D.Icon_Value,
                     D.Icon_Index, Natural (D.Icon_Keys.Length));
      Mapping_Group ("settings.open_action.buttons",
                     "settings.open_action_token", D.Open_Action_Token,
                     "settings.open_action_command", D.Open_Action_Command,
                     D.Open_Action_Index, Natural (D.Open_Action_Keys.Length));

      return Result;
   end Fields;

   --  Replace the selected entry's key or value (keeping the sync field and its
   --  vector element consistent; Set_Settings_Draft normalizes the rest).
   procedure Set_Entry
     (Keys, Values     : in out Files.Types.String_Vectors.Vector;
      Index            : Natural;
      Key_Field        : in out UString;
      Value_Field      : in out UString;
      Editing_Key      : Boolean;
      New_Value        : UString) is
   begin
      if Editing_Key then
         Key_Field := New_Value;
         if Index in 1 .. Natural (Keys.Length) then
            Keys.Replace_Element (Index, New_Value);
         end if;
      else
         Value_Field := New_Value;
         if Index in 1 .. Natural (Values.Length) then
            Values.Replace_Element (Index, New_Value);
         end if;
      end if;
   end Set_Entry;

   procedure Add_Entry
     (Keys, Values : in out Files.Types.String_Vectors.Vector;
      Index        : in out Natural;
      Key_Field    : out UString;
      Value_Field  : out UString) is
   begin
      Keys.Append (Null_Unbounded_String);
      Values.Append (Null_Unbounded_String);
      Index       := Natural (Keys.Length);
      Key_Field   := Null_Unbounded_String;
      Value_Field := Null_Unbounded_String;
   end Add_Entry;

   procedure Remove_Entry
     (Keys, Values : in out Files.Types.String_Vectors.Vector;
      Index        : in out Natural;
      Key_Field    : out UString;
      Value_Field  : out UString) is
   begin
      if Index in 1 .. Natural (Keys.Length) then
         Keys.Delete (Index);
         if Index <= Natural (Values.Length) then
            Values.Delete (Index);
         end if;
      end if;
      Index := Natural'Min (Index, Natural (Keys.Length));
      if Index in 1 .. Natural (Keys.Length) then
         Key_Field   := Keys.Element (Index);
         Value_Field := Values.Element (Index);
      else
         Key_Field   := Null_Unbounded_String;
         Value_Field := Null_Unbounded_String;
      end if;
   end Remove_Entry;

   --  Page the selected entry to the neighbouring one (wrapping), syncing the
   --  key/value fields to the new selection.
   procedure Navigate_Entry
     (Keys, Values : Files.Types.String_Vectors.Vector;
      Index        : in out Natural;
      Key_Field    : out UString;
      Value_Field  : out UString;
      Forward      : Boolean)
   is
      Count : constant Natural := Natural (Keys.Length);
   begin
      if Count = 0 then
         Index := 0;
         Key_Field := Null_Unbounded_String;
         Value_Field := Null_Unbounded_String;
         return;
      elsif Index < 1 then
         Index := 1;
      elsif Forward then
         Index := (if Index >= Count then 1 else Index + 1);
      else
         Index := (if Index <= 1 then Count else Index - 1);
      end if;
      Key_Field   := Keys.Element (Index);
      Value_Field := Values.Element (Index);
   end Navigate_Entry;

   --  Apply a mapping-group button (add / remove / prev / next) to a group.
   procedure Group_Button
     (Keys, Values : in out Files.Types.String_Vectors.Vector;
      Index        : in out Natural;
      Key_Field    : in out UString;
      Value_Field  : in out UString;
      Button       : String) is
   begin
      if Button = "add" then
         Add_Entry (Keys, Values, Index, Key_Field, Value_Field);
      elsif Button = "remove" then
         Remove_Entry (Keys, Values, Index, Key_Field, Value_Field);
      elsif Button = "prev" then
         Navigate_Entry (Keys, Values, Index, Key_Field, Value_Field, Forward => False);
      elsif Button = "next" then
         Navigate_Entry (Keys, Values, Index, Key_Field, Value_Field, Forward => True);
      end if;
   end Group_Button;

   function Apply
     (Model  : in out Files.Model.Window_Model;
      Change : Guikit.Settings_Panel.Change)
      return Boolean
   is
      D    : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      Key  : constant String  := To_String (Change.Key);
      Val  : constant UString := Change.Value;
      Save : Boolean := False;
   begin
      case Change.Kind is
         when SP.No_Change =>
            return False;

         when SP.Value_Changed =>
            if Key = "settings.view" then
               D.Default_View_Mode := Val;
               Save := True;
            elsif Key = "settings.hidden_files" then
               D.Show_Hidden_Files := Val;
               Save := True;
            elsif Key = "settings.sort" then
               D.Sort_Field_Value := Val;
               Save := True;
            elsif Key = "settings.sort_ascending" then
               D.Sort_Ascending := Val;
               Save := True;
            elsif Key = "settings.theme" then
               D.Theme := Val;
               Save := True;
            elsif Key = "settings.icon_theme" then
               D.Icon_Theme_Name := Val;
               Save := True;
            elsif Key = "settings.font_pixel_size" then
               D.Font_Pixel_Size := Val;
               Save := True;
            elsif Key = "settings.system_opener" then
               D.Use_System_Default_Opener := Val;
               Save := True;
            elsif Key = "settings.grouping" then
               D.Group_By := Val;
               Save := True;
            elsif Key = "settings.column.modified" then
               D.Column_Modified := Val;
               Save := True;
            elsif Key = "settings.column.size" then
               D.Column_Size := Val;
               Save := True;
            elsif Key = "settings.column.type" then
               D.Column_Filetype := Val;
               Save := True;
            elsif Key = "settings.column.created" then
               D.Column_Created := Val;
               Save := True;
            elsif Key = "settings.column.permissions" then
               D.Column_Permissions := Val;
               Save := True;
            elsif Key = "settings.filetype_extension" then
               Set_Entry (D.Filetype_Keys, D.Filetype_Values, D.Filetype_Index,
                          D.Filetype_Extension, D.Filetype_Value, Editing_Key => True, New_Value => Val);
            elsif Key = "settings.filetype_value" then
               Set_Entry (D.Filetype_Keys, D.Filetype_Values, D.Filetype_Index,
                          D.Filetype_Extension, D.Filetype_Value, Editing_Key => False, New_Value => Val);
            elsif Key = "settings.icon_filetype" then
               Set_Entry (D.Icon_Keys, D.Icon_Values, D.Icon_Index,
                          D.Icon_Filetype, D.Icon_Value, Editing_Key => True, New_Value => Val);
            elsif Key = "settings.icon_value" then
               Set_Entry (D.Icon_Keys, D.Icon_Values, D.Icon_Index,
                          D.Icon_Filetype, D.Icon_Value, Editing_Key => False, New_Value => Val);
            elsif Key = "settings.open_action_token" then
               Set_Entry (D.Open_Action_Keys, D.Open_Action_Commands, D.Open_Action_Index,
                          D.Open_Action_Token, D.Open_Action_Command, Editing_Key => True, New_Value => Val);
            elsif Key = "settings.open_action_command" then
               Set_Entry (D.Open_Action_Keys, D.Open_Action_Commands, D.Open_Action_Index,
                          D.Open_Action_Token, D.Open_Action_Command, Editing_Key => False, New_Value => Val);
            end if;
            D.Valid     := True;
            D.Error_Key := Null_Unbounded_String;

         when SP.Button_Pressed =>
            declare
               Button : constant String := To_String (Val);
            begin
               if Key = "settings.actions" then
                  if Button = "reset" then
                     D := Files.Settings.Reset_Draft_To_Defaults;
                  end if;
               elsif Key = "settings.filetype.buttons" then
                  Group_Button (D.Filetype_Keys, D.Filetype_Values, D.Filetype_Index,
                                D.Filetype_Extension, D.Filetype_Value, Button);
               elsif Key = "settings.icon.buttons" then
                  Group_Button (D.Icon_Keys, D.Icon_Values, D.Icon_Index,
                                D.Icon_Filetype, D.Icon_Value, Button);
               elsif Key = "settings.open_action.buttons" then
                  Group_Button (D.Open_Action_Keys, D.Open_Action_Commands, D.Open_Action_Index,
                                D.Open_Action_Token, D.Open_Action_Command, Button);
               end if;
               --  Prev/Next only page the selection; they redraw but do not save.
               Save := Button = "reset" or else Button = "add" or else Button = "remove";
            end;
            D.Valid     := True;
            D.Error_Key := Null_Unbounded_String;
      end case;

      Files.Model.Set_Settings_Draft (Model, D);
      return Save;
   end Apply;

end Files.Settings_Form;
