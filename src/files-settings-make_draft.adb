separate (Files.Settings)
   function Make_Draft
     (Settings : Settings_Model)
      return Settings_Draft is
      Extension     : Unbounded_String := Null_Unbounded_String;
      Filetype      : Unbounded_String := Null_Unbounded_String;
      Icon_Filetype : Unbounded_String := Null_Unbounded_String;
      Icon          : Unbounded_String := Null_Unbounded_String;
      Token         : Unbounded_String := Null_Unbounded_String;
      Command       : Unbounded_String := Null_Unbounded_String;
      Filetype_Keys : String_Vectors.Vector;
      Filetype_Values : String_Vectors.Vector;
      Icon_Keys     : String_Vectors.Vector;
      Icon_Values   : String_Vectors.Vector;
      Action_Keys   : String_Vectors.Vector;
      Action_Values : String_Vectors.Vector;
   begin
      if not Settings.Extension_Filetypes.Is_Empty then
         declare
            Keys : String_Vectors.Vector;
         begin
            for Cursor in Settings.Extension_Filetypes.Iterate loop
               Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
            end loop;
            Sort (Keys);
            for Key of Keys loop
               Filetype_Keys.Append (Key);
               Filetype_Values.Append (To_Unbounded_String (Settings.Extension_Filetypes.Element (To_String (Key))));
            end loop;
            Extension := Filetype_Keys.Element (1);
            Filetype := Filetype_Values.Element (1);
         end;
      end if;

      if not Settings.Icon_Mappings.Is_Empty then
         declare
            Keys : String_Vectors.Vector;
         begin
            for Cursor in Settings.Icon_Mappings.Iterate loop
               Keys.Append (To_Unbounded_String (String_Maps.Key (Cursor)));
            end loop;
            Sort (Keys);
            for Key of Keys loop
               Icon_Keys.Append (Key);
               Icon_Values.Append (To_Unbounded_String (Settings.Icon_Mappings.Element (To_String (Key))));
            end loop;
            Icon_Filetype := Icon_Keys.Element (1);
            Icon := Icon_Values.Element (1);
         end;
      end if;

      if not Settings.Open_Actions.Is_Empty then
         declare
            Keys : String_Vectors.Vector;
         begin
            for Cursor in Settings.Open_Actions.Iterate loop
               Keys.Append (To_Unbounded_String (Action_Maps.Key (Cursor)));
            end loop;
            Sort (Keys);
            for Key of Keys loop
               Action_Keys.Append (Key);
               Action_Values.Append
                 (To_Unbounded_String (Action_Text (Settings.Open_Actions.Element (To_String (Key)))));
            end loop;
            Token := Action_Keys.Element (1);
            Command := Action_Values.Element (1);
         end;
      end if;

      return
        (Default_View_Mode      => To_Unbounded_String (View_Mode_Name (Settings.Default_View)),
         Show_Hidden_Files      => To_Unbounded_String (Boolean_Name (Settings.Show_Hidden_Files)),
         Show_File_Extensions   => To_Unbounded_String (Boolean_Name (Settings.Show_File_Extensions)),
         Show_Used_Space        => To_Unbounded_String (Boolean_Name (Settings.Show_Used_Space)),
         Show_Space_Bar         => To_Unbounded_String (Boolean_Name (Settings.Show_Space_Bar)),
         Sort_Field_Value       => To_Unbounded_String (Sort_Field_Name (Settings.Sort_Field_Value)),
         Sort_Ascending         => To_Unbounded_String (Boolean_Name (Settings.Sort_Ascending)),
         Theme                  => To_Unbounded_String (Theme_Name (Settings.Theme)),
         Icon_Theme_Name        => Settings.Icon_Theme_Name,
         Font_Pixel_Size        => To_Unbounded_String (Trim (Positive'Image (Settings.Font_Pixel_Size))),
         Use_System_Default_Opener =>
           To_Unbounded_String (Boolean_Name (Settings.Use_System_Default_Opener)),
         Group_By               => To_Unbounded_String (Group_Mode_Name (Settings.Group_By)),
         Column_Modified        =>
           To_Unbounded_String (Boolean_Name (Settings.Column_Visible (Files.Types.Modified_Column))),
         Column_Size            =>
           To_Unbounded_String (Boolean_Name (Settings.Column_Visible (Files.Types.Size_Column))),
         Column_Filetype        =>
           To_Unbounded_String (Boolean_Name (Settings.Column_Visible (Files.Types.Filetype_Column))),
         Column_Created         =>
           To_Unbounded_String (Boolean_Name (Settings.Column_Visible (Files.Types.Created_Column))),
         Column_Permissions     =>
           To_Unbounded_String (Boolean_Name (Settings.Column_Visible (Files.Types.Permissions_Column))),
         Filetype_Extension     => Extension,
         Filetype_Value         => Filetype,
         Filetype_Keys          => Filetype_Keys,
         Filetype_Values        => Filetype_Values,
         Filetype_Index         => (if Filetype_Keys.Is_Empty then 0 else 1),
         Icon_Filetype          => Icon_Filetype,
         Icon_Value             => Icon,
         Icon_Keys              => Icon_Keys,
         Icon_Values            => Icon_Values,
         Icon_Index             => (if Icon_Keys.Is_Empty then 0 else 1),
         Open_Action_Token      => Token,
         Open_Action_Command    => Command,
         Open_Action_Keys       => Action_Keys,
         Open_Action_Commands   => Action_Values,
         Open_Action_Index      => (if Action_Keys.Is_Empty then 0 else 1),
         Error_Key              => Null_Unbounded_String,
         Valid                  => True);
   end Make_Draft;
