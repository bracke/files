package body Files.Rendering.Display_Text.Testing is

   function Calendar_Days_Ago (Value, Now : Ada.Calendar.Time) return Integer renames
     Files.Rendering.Display_Text.Calendar_Days_Ago;

end Files.Rendering.Display_Text.Testing;
