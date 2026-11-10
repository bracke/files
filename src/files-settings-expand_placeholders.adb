with Hostkit.Fs;
with Hostkit.Path_Text;
with Files.File_Types;

with Files.Diagnostics;
separate (Files.Settings)
   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action
   is
      --  Read as the whole path is: its separators and share root are
      --  Hostkit.Path_Text's, so a Windows path reads the same on any host.
      function Is_Path_Separator (Value : Character) return Boolean is
        (Hostkit.Path_Text.Is_Separator_In (Path, Value));

      function UNC_Share_Root_Last (Value : String) return Natural renames Hostkit.Path_Text.Share_Root_Last;

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
            if Last - Value'First + 1 = Hostkit.Fs.Drive_Root_Length (Value) then
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
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Settings");
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

         if Separator > 0 and then Separator - Value'First + 1 = Hostkit.Fs.Drive_Root_Length (Value) then
            return Value (Value'First .. Separator);
         elsif Separator > Value'First then
            return Value (Value'First .. Separator - 1);
         elsif Separator = Value'First then
            return Value (Value'First .. Value'First);
         end if;

         return Ada.Directories.Containing_Directory (Value);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Settings");
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

      Result    : Open_Action := Action;
      Clean     : constant String := Trim_Trailing_Path_Separators (Path);
      Name      : constant String := Safe_Simple_Name (Clean);
      Parent    : constant String := Safe_Containing_Directory (Clean);
      Extension : constant String := Files.File_Types.Extension_Of (Name);
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
