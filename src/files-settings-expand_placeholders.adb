with Hostkit.Path_Text;
with Files.Types;

separate (Files.Settings)
   function Expand_Placeholders
     (Action : Open_Action;
      Path   : String)
      return Open_Action
   is
      Result    : Open_Action := Action;
      --  Read as the whole path is (Hostkit.Path_Text): its separators,
      --  drive and share root the same on any host, a long name whole.
      Name      : constant String := Hostkit.Path_Text.Leaf (Path);
      Up        : constant String := Hostkit.Path_Text.Parent (Path);
      Parent    : constant String :=
        (if Path = "" then ""
         --  A root ("/", "C:\", "\\server\share\") stands for itself.
         elsif Name = "" then Path
         --  A name alone lies in the current directory.
         elsif Up = "" then "."
         else Up);
      --  As the name spells them (Files.Types' one rule): "{extension}" of
      --  "Photo.JPG" is "JPG", as "{stem}" is "Photo".
      Extension : constant String := Files.Types.Extension_Of (Name);
      Stem      : constant String := Files.Types.Stem_Of (Name);
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
