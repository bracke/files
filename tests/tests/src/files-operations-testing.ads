--  The suite's reach into Files.Operations' private part.
package Files.Operations.Testing is

   --  Settle whether the model's current directory is the trash's files
   --  directory, as a navigation does after it changes the directory.
   --
   --  @param Model Window model whose trash flag is settled.
   procedure Settle_Current_Is_Trash
     (Model : in out Files.Model.Window_Model);

end Files.Operations.Testing;
