--  What the suite reaches of Files.Rendering.Display_Text that is not part of its interface.
package Files.Rendering.Display_Text.Testing is

   --  How many calendar days before Now's Value falls: 0 today, 1 yesterday,
   --  negative in the future, counted from local midnights so a 23- or
   --  25-hour day still counts as one.
   --
   --  @param Value The earlier time.
   --  @param Now The present.
   --  @return The number of calendar days.
   function Calendar_Days_Ago (Value, Now : Ada.Calendar.Time) return Integer;

end Files.Rendering.Display_Text.Testing;
