with Files.Preference_Types;
with Ada.Strings;
with Ada.Strings.Unbounded;

with Files.Commands;
with Files.Diagnostics;
with Files.Icon_Themes;
with Files.Localization;
with Files.Model.Settings_Pane;
with Files.Types;
with Files.Text_Basics;

package body Files.Overlays.Settings_Form is

   use Ada.Strings.Unbounded;
   subtype UString is Ada.Strings.Unbounded.Unbounded_String;
   package SP renames Guikit.Settings_Panel;
   use type SP.Change_Kind;
   use all type Files.Settings.Scalar_Setting;
   use type Files.Commands.Command_Id;
   use type Files.Commands.Shortcut;

   Shortcut_Key_Prefix : constant String := "shortcut.";

   type Form_Key_Text is access constant String;
   function "+" (Text : String) return Form_Key_Text is (new String'(Text));

   --  The form field that edits each scalar setting; "" for the settings the
   --  pane does not show. Fields builds its rows and Apply reads changes back
   --  through this one table, so a row and its handling cannot drift apart.
   Form_Keys : constant array (Files.Settings.Scalar_Setting) of Form_Key_Text :=
     [Default_View_Mode_Setting         => +"settings.view",
      Show_Hidden_Files_Setting         => +"settings.hidden_files",
      Show_File_Extensions_Setting      => +"settings.show_extensions",
      Sort_Field_Setting                => +"settings.sort",
      Sort_Ascending_Setting            => +"settings.sort_ascending",
      Theme_Setting                     => +"settings.theme",
      Icon_Theme_Setting                => +"settings.icon_theme",
      Font_Pixel_Size_Setting           => +"settings.font_pixel_size",
      Use_System_Default_Opener_Setting => +"settings.system_opener",
      Group_By_Setting                  => +"settings.grouping",
      Detail_Column_Modified_Setting    => +"settings.column.modified",
      Detail_Column_Size_Setting        => +"settings.column.size",
      Detail_Column_Filetype_Setting    => +"settings.column.type",
      Detail_Column_Created_Setting     => +"settings.column.created",
      Detail_Column_Permissions_Setting => +"settings.column.permissions",
      others                            => +""];

   function Form_Key (Setting : Files.Settings.Scalar_Setting) return String is (Form_Keys (Setting).all);

   --  Whether Key is the form field of a scalar setting.
   function Is_Form_Scalar (Key : String) return Boolean is
     (Key /= "" and then (for some Setting in Files.Settings.Scalar_Setting => Form_Key (Setting) = Key));

   --  The scalar setting whose form field is Key.
   function Form_Scalar (Key : String) return Files.Settings.Scalar_Setting
     with Pre => Is_Form_Scalar (Key);

   function Form_Scalar (Key : String) return Files.Settings.Scalar_Setting is
   begin
      for Setting in Files.Settings.Scalar_Setting loop
         if Form_Key (Setting) = Key then
            return Setting;
         end if;
      end loop;
      raise Program_Error;
   end Form_Scalar;

   function U (S : String) return Unbounded_String renames To_Unbounded_String;
   function L (Key : String) return Unbounded_String is (U (Files.Localization.Text (Key)));
   function Img (N : Natural) return String renames Files.Text_Basics.Natural_Text;

   function Fields
     (Draft : Files.Settings.Settings_Draft)
      return SP.Field_Vectors.Vector
   is
      D      : Files.Settings.Settings_Draft renames Draft;
      Result : SP.Field_Vectors.Vector;

      procedure Section (Key : String) is
      begin
         Result.Append (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Section, others => <>));
      end Section;

      --  Help_Key names a settings.help.* catalog entry shown in the pane footer
      --  while the field is focused; the empty default leaves the field help-less.
      --  Each scalar row's key is its Form_Key and its value the draft's text.
      procedure Toggle (Setting : Files.Settings.Scalar_Setting; Help_Key : String := "") is
         Key : constant String := Form_Key (Setting);
      begin
         Result.Append
           (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Toggle, Value => D.Scalars (Setting),
                      Help => L (Help_Key), others => <>));
      end Toggle;

      procedure Choice
        (Key : String; Value : UString; Toks, Labels : SP.UString_Vectors.Vector; Help_Key : String := "") is
      begin
         Result.Append
           (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Choice, Value => Value,
                      Option_Values => Toks, Option_Labels => Labels, Help => L (Help_Key), others => <>));
      end Choice;

      --  A choice over every value of an enumeration, in declaration order:
      --  Token is the stored form (the settings file's spelling), Label_Key the
      --  catalog key shown for it.
      generic
         type Value_Type is (<>);
         with function Token (Value : Value_Type) return String;
         with function Label_Key (Value : Value_Type) return String;
      procedure Enum_Choice (Setting : Files.Settings.Scalar_Setting; Help_Key : String);

      procedure Enum_Choice (Setting : Files.Settings.Scalar_Setting; Help_Key : String) is
         Toks, Labels : SP.UString_Vectors.Vector;
      begin
         for Each in Value_Type loop
            Toks.Append (U (Token (Each)));
            Labels.Append (L (Label_Key (Each)));
         end loop;
         Choice (Form_Key (Setting), D.Scalars (Setting), Toks, Labels, Help_Key);
      end Enum_Choice;

      --  The view choice uses the same short labels as the bottom bar's
      --  view-mode selector.
      function View_Label_Key (Mode : Files.Preference_Types.View_Mode) return String is
        (case Mode is
            when Files.Preference_Types.Small_Icons => "command.view.small.short",
            when Files.Preference_Types.Large_Icons => "command.view.large.short",
            when Files.Preference_Types.Details     => "command.view.details.short");
      function Sort_Label_Key (Field : Files.Types.Sort_Field) return String is
        ("settings.sort." & Files.Settings.Sort_Field_Name (Field));
      function Theme_Label_Key (Theme : Files.Settings.Theme_Choice) return String is
        ("settings.theme." & Files.Settings.Theme_Name (Theme));
      function Icon_Theme_Label_Key (Theme : Files.Icon_Themes.Icon_Theme) return String is
        (case Theme is
            when Files.Icon_Themes.Basic         => "settings.icon_theme.basic",
            when Files.Icon_Themes.High_Contrast => "settings.icon_theme.high_contrast");
      function Group_Label_Key (Mode : Files.Preference_Types.Group_Mode) return String is
        ("settings.group." & Files.Settings.Group_Mode_Name (Mode));

      procedure View_Choice is new Enum_Choice
        (Files.Preference_Types.View_Mode, Files.Settings.View_Mode_Name, View_Label_Key);
      procedure Sort_Choice is new Enum_Choice
        (Files.Types.Sort_Field, Files.Settings.Sort_Field_Name, Sort_Label_Key);
      procedure Color_Theme_Choice is new Enum_Choice
        (Files.Settings.Theme_Choice, Files.Settings.Theme_Name, Theme_Label_Key);
      procedure Icon_Theme_Choice is new Enum_Choice
        (Files.Icon_Themes.Icon_Theme, Files.Icon_Themes.Image, Icon_Theme_Label_Key);
      procedure Group_Choice is new Enum_Choice
        (Files.Preference_Types.Group_Mode, Files.Settings.Group_Mode_Name, Group_Label_Key);

      procedure Number_Field
        (Setting : Files.Settings.Scalar_Setting; Min, Max : Integer; Help_Key : String := "")
      is
         Key : constant String := Form_Key (Setting);
      begin
         Result.Append
           (SP.Field'(Key => U (Key), Label => L (Key), Kind => SP.Number, Value => D.Scalars (Setting),
                      Min => Min, Max => Max, Help => L (Help_Key), others => <>));
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
         Count       : Natural;
         Key_Help    : String := "";
         Val_Help    : String := "")
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
           (SP.Field'(Key => U (Key_Key), Label => Key_Label, Kind => SP.Text, Value => Key_Value,
                      Help => L (Key_Help), others => <>));
         Result.Append
           (SP.Field'(Key => U (Val_Key), Label => L (Val_Key), Kind => SP.Text, Value => Val_Value,
                      Help => L (Val_Help), others => <>));
      end Mapping_Group;

      procedure Action_Buttons is
         Toks, Labels : SP.UString_Vectors.Vector;
      begin
         Toks.Append (U ("reset"));
         --  Name what it resets: the button sits apart from every field, and a
         --  bare "Reset" read as resetting the row beside it.
         Labels.Append (L ("command.settings.reset"));
         Result.Append
           (SP.Field'(Key => U ("form.actions"), Label => Null_Unbounded_String,
                      Kind => SP.Buttons, Option_Values => Toks, Option_Labels => Labels, others => <>));
      end Action_Buttons;

      --  One press-to-capture row per registered command. The field Key carries
      --  the stable command identifier so Apply can route the captured chord, and
      --  the Value shows the command's current effective shortcut.
      procedure Shortcut_Rows is
      begin
         for Cmd in Files.Commands.Registered_Command_Id loop
            declare
               Secondary : constant Files.Commands.Shortcut :=
                 Files.Commands.Secondary_Shortcut_For (Cmd);
               --  Lead with how to edit the binding (the footer's action hint),
               --  then append the built-in secondary.
               Help      : UString := L ("settings.help.shortcut");
            begin
               --  A built-in secondary shortcut is not edited on its own: it lasts
               --  until the command is rebound or unbound, so surface it
               --  read-only in the help line.
               if Secondary.Present then
                  if Length (Help) > 0 then
                     Append (Help, U (" - "));
                  end if;
                  Append (Help, L ("settings.shortcut.secondary"));
                  Append (Help, U (" "));
                  Append (Help, U (Files.Commands.Shortcut_Display_Text (Secondary)));
               end if;
               Result.Append
                 (SP.Field'
                    (Key   => U (Shortcut_Key_Prefix & Files.Commands.Identifier (Cmd)),
                     Label => L (Files.Commands.Name_Key (Cmd)),
                     Kind  => SP.Shortcut,
                     Value => U (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Cmd))),
                     --  Shown localized ("Strg+1"); Value stays the stored form
                     --  that capture and Apply parse.
                     Display => U (Files.Commands.Shortcut_Display_Text (Files.Commands.Shortcut_For (Cmd))),
                     Help  => Help,
                     others => <>));
            end;
         end loop;
      end Shortcut_Rows;
   begin
      Action_Buttons;
      Section ("settings.section.view");
      View_Choice (Default_View_Mode_Setting, "settings.help.default_view");
      Toggle (Show_Hidden_Files_Setting, "settings.help.boolean");
      Toggle (Show_File_Extensions_Setting, "settings.help.boolean");

      Section ("settings.section.sorting");
      Sort_Choice (Sort_Field_Setting, "settings.help.sort");
      Toggle (Sort_Ascending_Setting, "settings.help.boolean");

      Section ("settings.section.appearance");
      Color_Theme_Choice (Theme_Setting, "settings.help.theme");
      Icon_Theme_Choice (Icon_Theme_Setting, "settings.help.icon_theme");
      Number_Field
        (Font_Pixel_Size_Setting, Files.Settings.Min_Font_Pixel_Size, Files.Settings.Max_Font_Pixel_Size,
         "settings.help.font_pixel_size");

      Section ("settings.section.behavior");
      Toggle (Use_System_Default_Opener_Setting, "settings.help.system_opener");

      Section ("settings.section.details");
      Group_Choice (Group_By_Setting, "settings.help.grouping");
      Toggle (Detail_Column_Modified_Setting, "settings.help.column");
      Toggle (Detail_Column_Size_Setting, "settings.help.column");
      Toggle (Detail_Column_Filetype_Setting, "settings.help.column");
      Toggle (Detail_Column_Created_Setting, "settings.help.column");
      Toggle (Detail_Column_Permissions_Setting, "settings.help.column");

      Section ("settings.section.file_types");
      Mapping_Group ("form.filetype.buttons",
                     "settings.filetype_extension", D.Filetype_Extension,
                     "settings.filetype_value", D.Filetype_Value,
                     D.Filetype_Index, Natural (D.Filetype_Keys.Length),
                     "settings.help.filetype_extension", "settings.help.filetype_value");
      Mapping_Group ("form.icon.buttons",
                     "settings.icon_filetype", D.Icon_Filetype,
                     "settings.icon_value", D.Icon_Value,
                     D.Icon_Index, Natural (D.Icon_Keys.Length),
                     "settings.help.icon_filetype", "settings.help.icon_value");
      Mapping_Group ("form.open_action.buttons",
                     "settings.open_action_token", D.Open_Action_Token,
                     "settings.open_action_command", D.Open_Action_Command,
                     D.Open_Action_Index, Natural (D.Open_Action_Keys.Length),
                     "settings.help.open_action_token", "settings.help.open_action_command");

      Section ("settings.section.shortcuts");
      Shortcut_Rows;

      return Result;
   end Fields;

   procedure Add_Entry
     (Keys, Values : in out Files.Types.String_Vectors.Vector;
      Index        : in out Natural;
      Key_Field    : out UString;
      Value_Field  : out UString);

   --  Replace the selected entry's key or value (keeping the sync field and its
   --  vector element consistent; Set_Draft normalizes the rest). Typing into a
   --  group with no entries starts its first one, rather than an edit that
   --  names no row and is dropped.
   procedure Set_Entry
     (Keys, Values     : in out Files.Types.String_Vectors.Vector;
      Index            : in out Natural;
      Key_Field        : in out UString;
      Value_Field      : in out UString;
      Editing_Key      : Boolean;
      New_Value        : UString) is
   begin
      if Keys.Is_Empty and then Length (New_Value) > 0 then
         Add_Entry (Keys, Values, Index, Key_Field, Value_Field);
      end if;
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

   --  Route a captured chord (Combo, empty to unbind) to the command named by a
   --  "shortcut.<identifier>" field Key, updating the live Files.Commands override
   --  table. Applied is set when the binding changed; Conflict is set instead when
   --  a different command's live primary binding is the chord (the binding is
   --  left untouched). A chord held only by another command's built-in secondary
   --  is taken from it.
   --  A binding equal to the built-in default clears the override so an untouched
   --  keymap leaves no persisted [shortcuts] entry.
   procedure Apply_Shortcut
     (Field_Key : String;
      Combo     : String;
      Applied   : out Boolean;
      Conflict  : out Boolean)
   is
      Id : Files.Commands.Command_Id := Files.Commands.No_Command;
   begin
      Applied  := False;
      Conflict := False;
      if Field_Key'Length > Shortcut_Key_Prefix'Length
        and then Field_Key (Field_Key'First .. Field_Key'First + Shortcut_Key_Prefix'Length - 1)
                 = Shortcut_Key_Prefix
      then
         Id := Files.Commands.Id_For_Identifier
                 (Field_Key (Field_Key'First + Shortcut_Key_Prefix'Length .. Field_Key'Last));
      end if;
      if Id = Files.Commands.No_Command then
         return;
      end if;

      declare
         Parsed : constant Files.Commands.Shortcut := Files.Commands.Parse_Shortcut (Combo);
      begin
         if Parsed.Present then
            --  Only live bindings conflict. Another command's primary does;
            --  its built-in secondary does not: the chord moves to Id and that
            --  command keeps its primary alone (an override drops its secondary).
            for Other in Files.Commands.Registered_Command_Id loop
               if Other /= Id and then Files.Commands.Shortcut_For (Other) = Parsed then
                  Conflict := True;
                  return;
               end if;
            end loop;
            declare
               Owner : constant Files.Commands.Command_Id :=
                 Files.Commands.Find_By_Shortcut (Parsed.Key, Parsed.Modifiers);
            begin
               if Owner /= Files.Commands.No_Command and then Owner /= Id then
                  Files.Commands.Set_Shortcut_Override (Owner, Files.Commands.Shortcut_For (Owner));
               end if;
            end;
         end if;

         if Parsed = Files.Commands.Default_Shortcut_For (Id) then
            Files.Commands.Clear_Shortcut_Override (Id);
         else
            Files.Commands.Set_Shortcut_Override (Id, Parsed);
         end if;
         Applied := True;
      end;
   end Apply_Shortcut;

   function Reset_To_Defaults return Files.Settings.Settings_Draft is
   begin
      --  A full return to defaults drops the keyboard shortcut overrides too;
      --  the save that follows persists the default keymap (no [shortcuts]
      --  section).
      Files.Commands.Reset_Shortcut_Overrides;
      return Files.Settings.Reset_Draft_To_Defaults;
   end Reset_To_Defaults;

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

   procedure Apply_Shortcut_Overrides (Settings : in out Files.Settings.Settings_Model) is
   begin
      Files.Commands.Reset_Shortcut_Overrides;
      for Entry_Value of Settings.Shortcut_Overrides loop
         declare
            Id : constant Files.Commands.Command_Id :=
              Files.Commands.Id_For_Identifier (To_String (Entry_Value.Command));
         begin
            if Id /= Files.Commands.No_Command
              and then Files.Commands.Is_Valid_Shortcut_Text (To_String (Entry_Value.Combo))
            then
               Files.Commands.Set_Shortcut_Override
                 (Id, Files.Commands.Parse_Shortcut (To_String (Entry_Value.Combo)));
            end if;
         end;
      end loop;
      Store_Shortcut_Overrides (Settings);
   end Apply_Shortcut_Overrides;

   function Needs_Save
     (Saved   : Files.Settings.Settings_Model;
      Applied : Files.Settings.Settings_Model)
      return Boolean
   is
      With_Overrides : Files.Settings.Settings_Model := Applied;
   begin
      Store_Shortcut_Overrides (With_Overrides);
      return not Files.Settings.Same_Content (Saved, With_Overrides);
   end Needs_Save;

   function Needs_Save
     (Saved : Files.Settings.Settings_Model;
      Draft : Files.Settings.Settings_Draft)
      return Boolean
   is
      Applied : constant Files.Settings.Settings_Parse_Result := Files.Settings.Apply_Draft (Saved, Draft);
   begin
      return Applied.Success and then Needs_Save (Saved, Applied.Settings);
   end Needs_Save;

   function Apply
     (Draft     : in out Files.Settings.Settings_Draft;
      Change    : Guikit.Settings_Panel.Change;
      Saved     : Files.Settings.Settings_Model;
      Rechecked : out Boolean)
      return Boolean
   is
      D        : Files.Settings.Settings_Draft renames Draft;
      Key      : constant String  := To_String (Change.Key);
      Val      : constant UString := Change.Value;
      Save     : Boolean := False;
      Conflict : Boolean := False;
   begin
      Rechecked := False;
      case Change.Kind is
         when SP.No_Change =>
            return False;

         when SP.Value_Changed =>
            if Is_Form_Scalar (Key) then
               D.Scalars (Form_Scalar (Key)) := Val;
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
            elsif Key'Length > Shortcut_Key_Prefix'Length
              and then Key (Key'First .. Key'First + Shortcut_Key_Prefix'Length - 1) = Shortcut_Key_Prefix
            then
               Apply_Shortcut (Key, To_String (Val), Applied => Save, Conflict => Conflict);
            else
               --  Every value field Fields builds is handled above; one that
               --  is not is a form out of step with this, so it is traced.
               Files.Diagnostics.Trace ("Files.Overlays.Settings_Form", "unhandled_field=" & Key);
            end if;
            --  A change that is saved is checked by that save, which reports
            --  what it finds; a text edit is checked when Enter commits it,
            --  and until then the draft's error stands.
            if Save then
               D.Valid     := True;
               D.Error_Key := Null_Unbounded_String;
            end if;
            if Conflict then
               --  Report the clash in the footer; the row visually reverts on the
               --  next rebuild because the live binding was left unchanged.
               D.Valid     := False;
               D.Error_Key := U ("settings.shortcut.conflict");
            end if;

         when SP.Button_Pressed =>
            declare
               Button        : constant String := To_String (Val);
               Is_Reset      : constant Boolean := Key = "form.actions" and then Button = "reset";
            begin
               if Is_Reset then
                  D := Reset_To_Defaults;
               elsif Key = "form.filetype.buttons" then
                  Group_Button (D.Filetype_Keys, D.Filetype_Values, D.Filetype_Index,
                                D.Filetype_Extension, D.Filetype_Value, Button);
               elsif Key = "form.icon.buttons" then
                  Group_Button (D.Icon_Keys, D.Icon_Values, D.Icon_Index,
                                D.Icon_Filetype, D.Icon_Value, Button);
               elsif Key = "form.open_action.buttons" then
                  Group_Button (D.Open_Action_Keys, D.Open_Action_Commands, D.Open_Action_Index,
                                D.Open_Action_Token, D.Open_Action_Command, Button);
               end if;
               --  Prev/Next only page the selection: no save, and an error
               --  the draft shows still holds. Reset, add and remove change
               --  rows, so the draft is checked again, and saved when valid
               --  and the file would hold something else -- compared with
               --  what it holds, not with the draft before the button, which
               --  may carry text edits not yet saved. Reset also drops the
               --  shortcut overrides, which Needs_Save weighs with the rest.
               --  One Apply_Draft (it validates the draft) does both.
               if Is_Reset or else Button = "add" or else Button = "remove" then
                  declare
                     Applied : constant Files.Settings.Settings_Parse_Result :=
                       Files.Settings.Apply_Draft (Saved, D);
                  begin
                     Rechecked := True;
                     D.Valid := Applied.Success;
                     D.Error_Key := (if Applied.Success then Null_Unbounded_String else Applied.Error_Key);
                     Save := Applied.Success and then Needs_Save (Saved, Applied.Settings);
                  end;
               end if;
            end;
      end case;

      return Save;
   end Apply;

   procedure Begin_Edit
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
   is
      Draft : Files.Settings.Settings_Draft := Files.Settings.Make_Draft (Settings);
   begin
      Files.Settings.Normalize_Draft (Draft);
      Files.Model.Settings_Pane.Begin_Edit (Model, Draft, Fields (Draft), Saved => Settings);
   end Begin_Edit;

   procedure Set_Draft
     (Model : in out Files.Model.Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized : Files.Settings.Settings_Draft := Draft;
   begin
      Files.Settings.Normalize_Draft (Normalized);
      Files.Model.Settings_Pane.Set_Draft (Model, Normalized, Fields (Normalized));
   end Set_Draft;

   function Apply_Change
     (Model  : in out Files.Model.Window_Model;
      Change : Guikit.Settings_Panel.Change)
      return Boolean
   is
      Draft     : Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
      Save      : Boolean;
      Rechecked : Boolean;
   begin
      if Change.Kind = SP.No_Change then
         return False;
      end if;
      Save := Apply (Draft, Change, Files.Model.Settings_Pane.Saved_Of (Model), Rechecked);
      Set_Draft (Model, Draft);
      --  The error line says what the re-check found, as Enter's check
      --  does; a save that follows reports for itself.
      if Rechecked and then not Save then
         Files.Model.Set_Error (Model, (if Draft.Valid then "" else To_String (Draft.Error_Key)));
      end if;
      return Save;
   end Apply_Change;

   function Reset_Draft
     (Model : in out Files.Model.Window_Model)
      return Boolean is
     (Apply_Change
        (Model,
         (Kind  => SP.Button_Pressed,
          Key   => To_Unbounded_String ("form.actions"),
          Value => To_Unbounded_String ("reset"))));

   procedure Mark_Saved
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      Files.Model.Settings_Pane.Set_Saved (Model, Settings);
   end Mark_Saved;

end Files.Overlays.Settings_Form;
