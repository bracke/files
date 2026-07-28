separate (Files.Settings)
   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action
   is
      function Is_Path_Separator (Value : Character) return Boolean is
      begin
         return Value = '/' or else Value = '\';
      end Is_Path_Separator;

      function UNC_Share_Root_Last (Value : String) return Natural is
         Server_Start : Natural;
         Share_Start  : Natural;
      begin
         if Value'Length < 5
           or else not Is_Path_Separator (Value (Value'First))
           or else not Is_Path_Separator (Value (Value'First + 1))
         then
            return 0;
         end if;

         Server_Start := Value'First + 2;
         while Server_Start <= Value'Last and then Is_Path_Separator (Value (Server_Start)) loop
            Server_Start := Server_Start + 1;
         end loop;

         for Index in Server_Start .. Value'Last loop
            if Is_Path_Separator (Value (Index)) then
               Share_Start := Index + 1;
               while Share_Start <= Value'Last and then Is_Path_Separator (Value (Share_Start)) loop
                  Share_Start := Share_Start + 1;
               end loop;

               for Share_End in Share_Start .. Value'Last loop
                  if Is_Path_Separator (Value (Share_End)) then
                     return Share_End;
                  end if;
               end loop;

               return Value'Last;
            end if;
         end loop;

         return 0;
      end UNC_Share_Root_Last;

      function Trim_Trailing_Path_Separators (Value : String) return String is
         Last : Natural := Value'Last;
         UNC_Root_Last : constant Natural := UNC_Share_Root_Last (Value);
      begin
         if Value = "" then
            return "";
         end if;

         while Last > Value'First
           and then Is_Path_Separator (Value (Last))
         loop
            if Last = Value'First + 2 and then Value (Value'First + 1) = ':' then
               exit;
            elsif UNC_Root_Last > 0 and then Last <= UNC_Root_Last then
               exit;
            end if;

            Last := Last - 1;
         end loop;

         return Value (Value'First .. Last);
      end Trim_Trailing_Path_Separators;

      function Safe_Simple_Name (Value : String) return String is
         Separator : Natural := 0;
      begin
         if Value = "" then
            return "";
         elsif UNC_Share_Root_Last (Value) = Value'Last then
            return "";
         end if;

         for Index in reverse Value'Range loop
            if Is_Path_Separator (Value (Index)) then
               Separator := Index;
               exit;
            end if;
         end loop;

         if Separator > 0 and then Separator < Value'Last then
            return Value (Separator + 1 .. Value'Last);
         elsif Separator = Value'Last then
            return "";
         end if;

         return Ada.Directories.Simple_Name (Value);
      exception
         when others =>
            return Value;
      end Safe_Simple_Name;

      function Safe_Containing_Directory (Value : String) return String is
         Separator : Natural := 0;
      begin
         if Value = "" then
            return "";
         elsif UNC_Share_Root_Last (Value) = Value'Last then
            return Value;
         end if;

         for Index in reverse Value'Range loop
            if Is_Path_Separator (Value (Index)) then
               Separator := Index;
               exit;
            end if;
         end loop;

         if Separator = Value'First + 2
           and then Value (Value'First + 1) = ':'
         then
            return Value (Value'First .. Separator);
         elsif Separator > Value'First then
            return Value (Value'First .. Separator - 1);
         elsif Separator = Value'First then
            return Value (Value'First .. Value'First);
         end if;

         return Ada.Directories.Containing_Directory (Value);
      exception
         when others =>
            return "";
      end Safe_Containing_Directory;

      function Last_Extension_Dot (Name : String) return Natural is
      begin
         for Index in reverse Name'Range loop
            if Name (Index) = '.' then
               return Index;
            end if;
         end loop;

         return 0;
      end Last_Extension_Dot;

      function Stem_Of (Name : String) return String is
         Dot : constant Natural := Last_Extension_Dot (Name);
      begin
         if Dot = 0 or else Dot = Name'First then
            return Name;
         elsif Dot = Name'Last then
            return Name;
         end if;

         return Name (Name'First .. Dot - 1);
      end Stem_Of;

      function Extension_Of (Name : String) return String is
         Dot : constant Natural := Last_Extension_Dot (Name);
      begin
         if Dot = 0 or else Dot = Name'First or else Dot = Name'Last then
            return "";
         end if;

         return Normalize_Extension (Name (Dot + 1 .. Name'Last));
      end Extension_Of;

      Result    : Open_Action := Action;
      Clean     : constant String := Trim_Trailing_Path_Separators (Path);
      Name      : constant String := Safe_Simple_Name (Clean);
      Parent    : constant String := Safe_Containing_Directory (Clean);
      Extension : constant String := Extension_Of (Name);
      Stem      : constant String := Stem_Of (Name);
   begin
      Result.Arguments.Clear;
      for Argument of Action.Arguments loop
         declare
            Value : constant String := To_String (Argument);
         begin
            if Value = "{path}" then
               Result.Arguments.Append (To_Unbounded_String (Path));
            elsif Value = "{parent}" then
               Result.Arguments.Append (To_Unbounded_String (Parent));
            elsif Value = "{name}" then
               Result.Arguments.Append (To_Unbounded_String (Name));
            elsif Value = "{stem}" then
               Result.Arguments.Append (To_Unbounded_String (Stem));
            elsif Value = "{extension}" then
               Result.Arguments.Append (To_Unbounded_String (Extension));
            else
               Result.Arguments.Append (Argument);
            end if;
         end;
      end loop;

      return Result;
   end Expand_Placeholders;
