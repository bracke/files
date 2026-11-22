--  What the suite reaches of Files.Commands.Status that is not part of its interface.
package Files.Commands.Status.Testing is

   --  @param Model Current window model.
   --  @return True when the host has a trash folder to go to, as the window
   --    sampled it (or a model no window sampled, which takes it to have one).
   function Trash_Available (Model : Files.Model.Window_Model) return Boolean;

end Files.Commands.Status.Testing;
