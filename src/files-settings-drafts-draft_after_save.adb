separate (Files.Settings.Drafts)
   function Draft_After_Save
     (Draft : Settings_Draft;
      Saved : Settings_Model)
      return Settings_Draft
   is
      Result : Settings_Draft := Make_Draft (Saved);

      --  Rebuild one mapping of Result from its saved rows in the order the
      --  pane showed them, and put its editor back where it was.
      --
      --  @param Kind Which mapping, for how its keys are normalized.
      --  @param Was_Keys The pane's keys before the save.
      --  @param Was_Values Its values before the save.
      --  @param Was_Index The row its editor was on (0 when none).
      --  @param Keys The saved keys (Make_Draft's order), replaced by the
      --    rows in the pane's order.
      --  @param Values The saved values, likewise.
      --  @param Index Set to the row the editor is on now.
      procedure Keep_Rows
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
         Saved_Count : constant Natural := Natural (Keys.Length);
         --  Where each saved row went in the new order (0: not yet placed),
         --  and where each of the pane's rows is now (0: dropped).
         Placed_At  : array (1 .. Saved_Count) of Natural := [others => 0];
         Now_At     : array (1 .. Natural'Max (Was_Count, 1)) of Natural := [others => 0];
         New_Keys   : String_Vectors.Vector;
         New_Values : String_Vectors.Vector;
      begin
         --  The pane's rows first, in its order: a row whose key another took
         --  (or the same key in another form) is the one saved row; a blank
         --  row in the middle is dropped, as the file does not hold it.
         for Row in 1 .. Was_Count loop
            if not Blank_Row (Was_Keys, Was_Values, Row) then
               declare
                  Key : constant String := Draft_Mapping_Key_Text (Kind, Was_Keys.Element (Row));
               begin
                  for Saved_Row in 1 .. Saved_Count loop
                     if To_String (Keys.Element (Saved_Row)) = Key then
                        if Placed_At (Saved_Row) = 0 then
                           New_Keys.Append (Keys.Element (Saved_Row));
                           New_Values.Append (Values.Element (Saved_Row));
                           Placed_At (Saved_Row) := Natural (New_Keys.Length);
                        end if;
                        Now_At (Row) := Placed_At (Saved_Row);
                        exit;
                     end if;
                  end loop;
               end;
            end if;
         end loop;
         --  A saved row the pane did not show (none, as it saved them all)
         --  is still listed, after the pane's.
         for Saved_Row in 1 .. Saved_Count loop
            if Placed_At (Saved_Row) = 0 then
               New_Keys.Append (Keys.Element (Saved_Row));
               New_Values.Append (Values.Element (Saved_Row));
            end if;
         end loop;
         --  A row just added at the end and not filled in stays there.
         if Had_Blank then
            New_Keys.Append (Null_Unbounded_String);
            New_Values.Append (Null_Unbounded_String);
            Now_At (Was_Count) := Natural (New_Keys.Length);
         end if;
         Keys := New_Keys;
         Values := New_Values;

         --  The editor's row, or failing that (a blank row dropped) the
         --  nearest row before it that is still there, then the nearest after.
         Index := 0;
         if Was_Index in 1 .. Was_Count then
            for Row in reverse 1 .. Was_Index loop
               if Now_At (Row) > 0 then
                  Index := Now_At (Row);
                  exit;
               end if;
            end loop;
            if Index = 0 then
               for Row in Was_Index + 1 .. Was_Count loop
                  if Now_At (Row) > 0 then
                     Index := Now_At (Row);
                     exit;
                  end if;
               end loop;
            end if;
         end if;
         if Index = 0 and then not Keys.Is_Empty then
            Index := 1;
         end if;
      end Keep_Rows;
   begin
      Keep_Rows
        (Draft_Filetype_Mapping, Draft.Filetype_Keys, Draft.Filetype_Values, Draft.Filetype_Index,
         Result.Filetype_Keys, Result.Filetype_Values, Result.Filetype_Index);
      Keep_Rows
        (Draft_Icon_Mapping, Draft.Icon_Keys, Draft.Icon_Values, Draft.Icon_Index,
         Result.Icon_Keys, Result.Icon_Values, Result.Icon_Index);
      Keep_Rows
        (Draft_Open_Action_Mapping, Draft.Open_Action_Keys, Draft.Open_Action_Commands, Draft.Open_Action_Index,
         Result.Open_Action_Keys, Result.Open_Action_Commands, Result.Open_Action_Index);
      --  The selected keys and values follow the rows (Normalize_Draft).
      Normalize_Draft (Result);
      return Result;
   end Draft_After_Save;
