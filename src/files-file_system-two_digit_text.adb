separate (Files.File_System)
   function Two_Digit_Text (Value : Natural) return String is
      Clean : constant String := Natural_Text (Value);
   begin
      if Value < 10 then
         return "0" & Clean;
      end if;

      return Clean;
   end Two_Digit_Text;
