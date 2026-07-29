separate (Files.File_System)
   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
   is
      Year      : Ada.Calendar.Year_Number;
      Month     : Ada.Calendar.Month_Number;
      Day       : Ada.Calendar.Day_Number;
      Seconds   : Ada.Calendar.Day_Duration;
      Remaining : Ada.Calendar.Day_Duration;
      Hour      : Natural := 0;
      Minute    : Natural := 0;
      Second    : Natural := 0;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      Remaining := Seconds;

      while Remaining >= 3_600.0 loop
         Hour := Hour + 1;
         Remaining := Remaining - 3_600.0;
      end loop;

      while Remaining >= 60.0 loop
         Minute := Minute + 1;
         Remaining := Remaining - 60.0;
      end loop;

      while Remaining >= 1.0 loop
         Second := Second + 1;
         Remaining := Remaining - 1.0;
      end loop;

      return
        Natural_Text (Natural (Year)) & "-"
        & Two_Digit_Text (Natural (Month)) & "-"
        & Two_Digit_Text (Natural (Day)) & "T"
        & Two_Digit_Text (Hour) & ":"
        & Two_Digit_Text (Minute) & ":"
        & Two_Digit_Text (Second);
   end Trash_Deletion_Date;
