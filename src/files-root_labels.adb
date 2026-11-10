with Ada.Strings.Unbounded;
with Files.Localization;

package body Files.Root_Labels is
   use Ada.Strings.Unbounded;

   function Display_Label (Root : Files.File_System.Root_Entry) return String is
      Label : constant String := To_String (Root.Label);
      Name  : constant String := To_String (Root.Name);

      function Base return String is
      begin
         if Name /= "" then
            return Files.Localization.Text (Label, "name", Name);
         elsif Label'Length >= 5 and then Label (Label'First .. Label'First + 4) = "root." then
            return Files.Localization.Text (Label);
         elsif Label /= "" then
            return Label;
         else
            return To_String (Root.Path);
         end if;
      end Base;
   begin
      if Length (Root.Detail) = 0 then
         return Base;
      end if;
      return Files.Localization.Text
        ("root.detail",
         Files.Localization.Argument_List'
           [(To_Unbounded_String ("label"), To_Unbounded_String (Base)),
            (To_Unbounded_String ("detail"), Root.Detail)]);
   end Display_Label;

end Files.Root_Labels;
