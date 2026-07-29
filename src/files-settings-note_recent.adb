separate (Files.Settings)
   procedure Note_Recent
     (Settings : in out Settings_Model;
      Path     : String)
   is
      Index : Natural;
   begin
      if Path = "" then
         return;
      end if;

      --  Drop any earlier occurrence so the freshest position wins and the list
      --  stays duplicate-free.
      Index := Settings.Recent_Paths_Value.First_Index;
      while Index <= Settings.Recent_Paths_Value.Last_Index loop
         if To_String (Settings.Recent_Paths_Value.Element (Index)) = Path then
            Settings.Recent_Paths_Value.Delete (Index);
         else
            Index := Index + 1;
         end if;
      end loop;

      Settings.Recent_Paths_Value.Prepend (To_Unbounded_String (Path));

      --  Enforce the cap by discarding the oldest (tail) entries.
      while Natural (Settings.Recent_Paths_Value.Length) > Max_Recent_Items loop
         Settings.Recent_Paths_Value.Delete_Last;
      end loop;
   end Note_Recent;
