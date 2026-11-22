package body Files.Commands.Status.Testing is

   function Trash_Available (Model : Files.Model.Window_Model) return Boolean
     renames Files.Commands.Status.Trash_Available;

end Files.Commands.Status.Testing;
