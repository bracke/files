with Ada.Calendar;
with Files.Rendering.Display_Text;
with Files_Suite.Support.Guards;
separate (Files_Suite.Rendering)
   --  A modification time is written in CLDR's medium form for the time
   --  locale -- its order, its month names, its hour cycle -- not one
   --  pattern for every locale.
   procedure Test_Full_Times_Use_The_Locale_Form (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
      Moment      : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (2026, 11, 22, 14.0 * 3_600.0 + 5.0 * 60.0 + 9.0);
   begin
      Files_Suite.Support.Guards.Save (Environment, "LC_ALL");
      Files_Suite.Support.Guards.Save (Environment, "LC_TIME");
      Files_Suite.Support.Guards.Save (Environment, "LANG");

      Ada.Environment_Variables.Set ("LC_ALL", "de_DE.UTF-8");
      Files.Localization.Reread_Locale_Environment;
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Display_Text.Full_Time_Text (Moment), "22.11.2026 14:05:09", "German date and time");
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Display_Text.Clock_Time_Text (Moment), "14:05:09", "German time");

      Ada.Environment_Variables.Set ("LC_ALL", "en_US.UTF-8");
      Files.Localization.Reread_Locale_Environment;
      declare
         Full : constant String := Files.Rendering.Display_Text.Full_Time_Text (Moment);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Full, "Nov 22, 2026") > 0 and then Ada.Strings.Fixed.Index (Full, "2:05:09") > 0,
            "English month name first, 12-hour clock: " & Full);
      end;
   end Test_Full_Times_Use_The_Locale_Form;
