with Files.Interaction;

package body Files.Settings_Sharing is

   procedure Share_From
     (Windows : in out Window_Set;
      First   : Positive;
      Last    : Natural;
      Source  : Positive) is
   begin
      if Revision (Windows, Source) = Synced_Revision (Windows, Source) then
         return;
      end if;

      for Other in First .. Last loop
         if Other /= Source then
            Adopt (Windows, Target => Other, Source => Source);
         end if;
         Mark_Synced (Windows, Other, Revision (Windows, Other));
      end loop;
   end Share_From;

   procedure Adopt_Window
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Shared            : Files.Settings.Settings_Model;
      Frame_Cache_Valid : out Boolean) is
   begin
      Files.Interaction.Adopt_Shared_Settings (Model => Model, Settings => Settings, Shared => Shared);
      Frame_Cache_Valid := False;
   end Adopt_Window;

end Files.Settings_Sharing;
