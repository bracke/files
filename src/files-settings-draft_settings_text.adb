separate (Files.Settings)
   function Draft_Settings_Text
     (Draft : Settings_Draft)
      return String
   is
      Rows            : constant Settings_Draft := With_Pending_Rows (Draft);
      Filetype_Keys   : String_Vectors.Vector renames Rows.Filetype_Keys;
      Filetype_Values : String_Vectors.Vector renames Rows.Filetype_Values;
      Icon_Keys       : String_Vectors.Vector renames Rows.Icon_Keys;
      Icon_Values     : String_Vectors.Vector renames Rows.Icon_Values;
      Action_Keys     : String_Vectors.Vector renames Rows.Open_Action_Keys;
      Action_Values   : String_Vectors.Vector renames Rows.Open_Action_Commands;
      Result          : Unbounded_String := Null_Unbounded_String;

      procedure Append_Line (Text : String := "") is
      begin
         Append (Result, Text);
         Append (Result, ASCII.LF);
      end Append_Line;
   begin
      --  The draft text is what Validate_Draft parses, so it carries the draft
      --  values verbatim (an invalid one must reach Parse to be reported). A
      --  required slot is always written, so an empty value is rejected; an
      --  optional slot only when it holds a value, so a bare draft round-trips
      --  to defaults. Settings the pane does not edit are left out.
      Append_Line ("[settings]");
      for Setting in Scalar_Setting loop
         case Scalar_Table (Setting).Pane is
            when Not_In_Pane =>
               null;
            when Pane_Required =>
               Append_Line (Scalar_Line (Setting, To_String (Draft.Scalars (Setting))));
            when Pane_Optional =>
               if Length (Draft.Scalars (Setting)) > 0 then
                  Append_Line (Scalar_Line (Setting, To_String (Draft.Scalars (Setting))));
               end if;
         end case;
      end loop;

      if not Filetype_Keys.Is_Empty then
         Append_Line ("[filetypes]");
         for Index in 1 .. Natural (Filetype_Keys.Length) loop
            if not Blank_Row (Filetype_Keys, Filetype_Values, Index) then
               Append_Line
                 (To_String (Filetype_Keys.Element (Index))
                  & " = "
                  & Action_Token_Text (To_String (Filetype_Values.Element (Index))));
            end if;
         end loop;
      end if;

      if not Icon_Keys.Is_Empty then
         Append_Line ("[icons]");
         for Index in 1 .. Natural (Icon_Keys.Length) loop
            if not Blank_Row (Icon_Keys, Icon_Values, Index) then
               Append_Line
                 (To_String (Icon_Keys.Element (Index))
                  & " = "
                  & Action_Token_Text (To_String (Icon_Values.Element (Index))));
            end if;
         end loop;
      end if;

      if not Action_Keys.Is_Empty then
         Append_Line ("[open-actions]");
         for Index in 1 .. Natural (Action_Keys.Length) loop
            if not Blank_Row (Action_Keys, Action_Values, Index) then
               Append_Line
                 (To_String (Action_Keys.Element (Index)) & " = " & To_String (Action_Values.Element (Index)));
            end if;
         end loop;
      end if;

      return To_String (Result);
   end Draft_Settings_Text;
