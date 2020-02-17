# Collision Notes

* For each object, the three bytes at offsets 16, 17, and 18 (relative to the start of that object's data) affect collision, but in an unclear way. They don't specify the dimensions of the object's collision volume (assuming a rectangular prism, this was a possibility), nor are they the indices of vertices that should be used to establish the corners of the collision volume.
  * Tests (using the burglar's car):
    * 250 0 0: no collision
    * 0 250 0: very small collision volume in the centre
    * 0 0 250: large volume to the left and in front of the vehicle
    * 250 0 250: just like 0 250 0
    * 250 250 250: just like 0 0 250
    * 250 250 0: no collision
    * 125 250 0: no collision
    * 0 0 50: very small collision volume in the centre (like 0 250 0)
    * 0 0 128: very small collision volume in the centre (like 0 250 0)
    * 0 0 200: very small collision volume in the centre (like 0 250 0)
    * 0 250 50: very small collision volume in the centre (like 0 250 0)
    * 250 250 50: very small collision volume in the centre (like 0 250 0)
    * 50 50 50: very small collision volume in the centre (like 0 250 0)
* For SimCopter's models, the byte at offset 19 is almost always zero and may not be collision-related.
  * There are four models that have it set to 1:
    * The Launch arcology (sim3d1.max, index 27, offset 108453)
    * The Braun Llama Dome (sim3d1.max, index 28, offset 136416)
    * The skyscraper with an extruded brown triangle on its roof (sim3d1.max, index 35, offset 195343)
    * The Darco arcology(sim3d3.max, index 79, offset 378433)
  * Besides being buildings, there is no obvious common attribute shared by these models.
