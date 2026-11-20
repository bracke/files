separate (Files.Settings)
   function Draft_After_Save
     (Draft : Settings_Draft;
      Saved : Settings_Model)
      return Settings_Draft
   is
      Result : Settings_Draft := Make_Draft (Saved);

      --  Put one mapping editor of Result back where it was in Draft.
      --
      --  @param Kind Which mapping, for how its keys are normalized.
      --  @param Was_Keys The editor's keys before the save.
      --  @param Was_Values Its values before the save.
      --  @param Was_Index The row it was on (0 when none).
      --  @param Keys The saved keys, a kept blank row appended.
      --  @param Values The saved values, likewise.
      --  @param Index Set to the row it is on now.
      procedure Keep_Position
        (Kind       : Draft_Mapping_Kind;
         Was_Keys   : String_Vectors.Vector;
         Was_Values : String_Vectors.Vector;
         Was_Index  : Natural;
         Keys       : in out String_Vectors.Vector;
         Values     : in out String_Vectors.Vector;
         Index      : out Natural)
      is
         Was_Count : constant Natural := Natural'Min (Natural (Was_Keys.Length), Natural (Was_Values.Length));
         Had_Blank : constant Boolean :=
           Was_Count > 0 and then Blank_Row (Was_Keys, Was_Values, Was_Count);
      begin
         if Had_Blank then
            Keys.Append (Null_Unbounded_String);
            Values.Append (Null_Unbounded_String);
         end if;
         Index := Natural'Min (Was_Index, Natural (Keys.Length));
         if Was_Index in 1 .. Was_Count and then not Blank_Row (Was_Keys, Was_Values, Was_Index) then
            declare
               Key : constant String := Draft_Mapping_Key_Text (Kind, Was_Keys.Element (Was_Index));
            begin
               for Row in 1 .. Natural (Keys.Length) loop
                  if To_String (Keys.Element (Row)) = Key then
                     Index := Row;
                     exit;
                  end if;
               end loop;
            end;
         elsif Had_Blank and then Was_Index = Was_Count then
            Index := Natural (Keys.Length);
         end if;
         if Index = 0 and then not Keys.Is_Empty then
            Index := 1;
         end if;
      end Keep_Position;
   begin
      Keep_Position
        (Draft_Filetype_Mapping, Draft.Filetype_Keys, Draft.Filetype_Values, Draft.Filetype_Index,
         Result.Filetype_Keys, Result.Filetype_Values, Result.Filetype_Index);
      Keep_Position
        (Draft_Icon_Mapping, Draft.Icon_Keys, Draft.Icon_Values, Draft.Icon_Index,
         Result.Icon_Keys, Result.Icon_Values, Result.Icon_Index);
      Keep_Position
        (Draft_Open_Action_Mapping, Draft.Open_Action_Keys, Draft.Open_Action_Commands, Draft.Open_Action_Index,
         Result.Open_Action_Keys, Result.Open_Action_Commands, Result.Open_Action_Index);
      --  The selected keys and values follow the rows (Normalize_Draft).
      Normalize_Draft (Result);
      return Result;
   end Draft_After_Save;
