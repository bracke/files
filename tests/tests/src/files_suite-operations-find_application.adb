separate (Files_Suite.Operations)
   function Find_Application
     (Apps : Files.Applications.Application_Vectors.Vector;
      Name : String)
      return Files.Applications.Application is
   begin
      for App of Apps loop
         if To_String (App.Name) = Name then
            return App;
         end if;
      end loop;
      return
        (Name         => Null_Unbounded_String,
         Exec         => Null_Unbounded_String,
         Icon         => Null_Unbounded_String,
         Desktop_File => Null_Unbounded_String);
   end Find_Application;
