package body Files.Icon_Themes is

   --  Name lower-cased with surrounding blanks removed.
   function Clean (Name : String) return String is
      First : Natural := Name'First;
      Last  : Natural := Name'Last;
   begin
      while First <= Last and then Name (First) in ' ' | ASCII.HT loop
         First := First + 1;
      end loop;
      while Last >= First and then Name (Last) in ' ' | ASCII.HT loop
         Last := Last - 1;
      end loop;
      return Result : String (1 .. Last - First + 1) do
         for Index in Result'Range loop
            Result (Index) :=
              (if Name (First + Index - 1) in 'A' .. 'Z'
               then Character'Val (Character'Pos (Name (First + Index - 1)) + 32)
               else Name (First + Index - 1));
         end loop;
      end return;
   end Clean;

   function Is_Name (Name : String) return Boolean is
      Text : constant String := Clean (Name);
   begin
      return (for some Theme in Icon_Theme => Image (Theme) = Text);
   end Is_Name;

   function Value (Name : String) return Icon_Theme is
      Text : constant String := Clean (Name);
   begin
      for Theme in Icon_Theme loop
         if Image (Theme) = Text then
            return Theme;
         end if;
      end loop;
      return Basic;
   end Value;

end Files.Icon_Themes;
