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
      Scalars       : Scalar_Texts;
   begin
      for Setting in Scalar_Setting loop
         if Is_Pane_Setting (Setting) then
            Scalars (Setting) := To_Unbounded_String (Scalar_Text (Settings, Setting));
         end if;
      end loop;

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
        (Scalars                => Scalars,
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
