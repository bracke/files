with Files.Settings.Drafts;
with Files.Preference_Types;
with Ada.Strings;
with Ada.Strings.Unbounded;

with Files.Commands;
with Files.Commands.Keymap_Settings;
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
   is separate;

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
   --  "shortcut.<identifier>" field Key, in the keymap the draft's Overrides
   --  describe; the live keymap changes only when a save of the draft is
   --  accepted. Applied is set when the binding changed; Conflict is set
   --  instead when a different command's primary binding is the chord (the
   --  binding is left untouched). A chord held only by another command's
   --  built-in secondary is taken from it.
   --  A binding equal to the built-in default clears the override so an untouched
   --  keymap leaves no persisted [shortcuts] entry.
   procedure Apply_Shortcut
     (Overrides : in out Files.Settings.Shortcut_Override_Vectors.Vector;
      Field_Key : String;
      Combo     : String;
      Applied   : out Boolean;
      Conflict  : out Boolean)
   is
      Id  : Files.Commands.Command_Id := Files.Commands.No_Command;
      Map : Files.Commands.Keymap := Files.Commands.Keymap_Settings.Keymap_Of (Overrides);
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
            --  Only bindings in force conflict. Another command's primary
            --  does; its built-in secondary does not: the chord moves to Id
            --  and that command keeps its primary alone (an override drops
            --  its secondary).
            for Other in Files.Commands.Registered_Command_Id loop
               if Other /= Id and then Files.Commands.Shortcut_For (Map, Other) = Parsed then
                  Conflict := True;
                  return;
               end if;
            end loop;
            declare
               Owner : constant Files.Commands.Command_Id :=
                 Files.Commands.Find_By_Shortcut (Map, Parsed.Key, Parsed.Modifiers);
            begin
               if Owner /= Files.Commands.No_Command and then Owner /= Id then
                  Files.Commands.Set_Shortcut_Override (Map, Owner, Files.Commands.Shortcut_For (Map, Owner));
               end if;
            end;
         end if;

         if Parsed = Files.Commands.Default_Shortcut_For (Id) then
            Files.Commands.Clear_Shortcut_Override (Map, Id);
         else
            Files.Commands.Set_Shortcut_Override (Map, Id, Parsed);
         end if;
         Overrides := Files.Commands.Keymap_Settings.Overrides_Of (Map);
         Applied := True;
      end;
   end Apply_Shortcut;

   --  A full return to defaults: the draft's shortcut overrides go too (the
   --  default draft has none), so the save that follows persists the default
   --  keymap (no [shortcuts] section) and puts it in force.
   function Reset_To_Defaults return Files.Settings.Settings_Draft is
     (Files.Settings.Drafts.Reset_Draft_To_Defaults);

   function Needs_Save
     (Saved   : Files.Settings.Settings_Model;
      Applied : Files.Settings.Settings_Model)
      return Boolean
   is
   begin
      return not Files.Settings.Same_Content (Saved, Applied);
   end Needs_Save;

   function Needs_Save
     (Saved : Files.Settings.Settings_Model;
      Draft : Files.Settings.Settings_Draft)
      return Boolean
   is
      Applied : constant Files.Settings.Settings_Parse_Result := Files.Settings.Drafts.Apply_Draft (Saved, Draft);
   begin
      return Applied.Success and then Needs_Save (Saved, Applied.Settings);
   end Needs_Save;

   --  Apply a change emitted by the panel to a draft. Reset (to the
   --  defaults, dropping every shortcut override), add and remove re-check
   --  the draft (its Valid and Error_Key say what holds now) and ask for a
   --  save when it is valid and Needs_Save against Saved; Prev/Next only
   --  page. A toggle, choice, number or captured shortcut asks for a save,
   --  which re-checks the draft; a text edit does not (the controller saves
   --  it on commit). Only a re-check or a save changes the draft's error.
   --
   --  @param Draft The draft to update.
   --  @param Change The change the panel produced.
   --  @param Saved The settings as saved.
   --  @param Rechecked Set when the draft was re-checked (reset, add, remove).
   --  @return True when the caller should save.
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
              and then Files.Text_Basics.Starts_With (Key, Shortcut_Key_Prefix)
            then
               Apply_Shortcut (D.Shortcut_Overrides, Key, To_String (Val), Applied => Save, Conflict => Conflict);
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
                       Files.Settings.Drafts.Apply_Draft (Saved, D);
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
      Draft : Files.Settings.Settings_Draft := Files.Settings.Drafts.Make_Draft (Settings);
   begin
      Files.Settings.Drafts.Normalize_Draft (Draft);
      Files.Model.Settings_Pane.Begin_Edit (Model, Draft, Fields (Draft), Saved => Settings);
   end Begin_Edit;

   procedure Set_Draft
     (Model : in out Files.Model.Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized : Files.Settings.Settings_Draft := Draft;
   begin
      Files.Settings.Drafts.Normalize_Draft (Normalized);
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
