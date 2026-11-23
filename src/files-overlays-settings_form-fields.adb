separate (Files.Overlays.Settings_Form)
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
      --  the Value shows the command's shortcut as the draft has it.
      procedure Shortcut_Rows is
         Map : constant Files.Commands.Keymap := Files.Commands.Keymap_Settings.Keymap_Of (D.Shortcut_Overrides);
      begin
         for Cmd in Files.Commands.Registered_Command_Id loop
            declare
               Secondary : constant Files.Commands.Shortcut :=
                 Files.Commands.Secondary_Shortcut_For (Map, Cmd);
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
                     Value => U (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Map, Cmd))),
                     --  Shown localized ("Strg+1"); Value stays the stored form
                     --  that capture and Apply parse.
                     Display => U (Files.Commands.Shortcut_Display_Text (Files.Commands.Shortcut_For (Map, Cmd))),
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
