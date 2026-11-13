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

end Files.Settings_Sharing;
