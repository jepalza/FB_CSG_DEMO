/' 
 *  Simple trackball-like motion adapted (ripped off) from projtex.c
 *  (written by David Yu and David Blythe).  See the SIGGRAPH ´96
 *  Advanced OpenGL course notes.
 *
 *  Usage:
 *  
 *  o  call tbInit() in before any other tb call
 *  o  call tbReshape() from the reshape callback
 *  o  call tbMatrix() to get the trackball matrix rotation
 *  o  call tbStartMotion() to begin trackball movememt
 *  o  call tbStopMotion() to stop trackball movememt
 *  o  call tbMotion() from the motion callback
 *  o  call tbAnimate(GL_TRUE) if you want the trackball to continue 
 *     spinning after the mouse button has been released
 *  o  call tbAnimate(GL_FALSE) if you want the trackball to stop 
 *     spinning after the mouse button has been released
 *
 *    conversion FREEBASIC Joseba Epalza (jepalza)
 * '/


/' includes '/
#Include "GL/gl.bi"
#include "GL/glut.bi"

 
 
/' funciones a llamar desde el modulo principal '/
Declare Sub tbInit(button As GLuint )  
Declare Sub tbMatrix()  
Declare Sub tbReshape(ancho As Integer , alto As Integer )  
Declare Sub tbMouse(button As Integer , state As Integer , x As Integer , y As Integer )  
Declare Sub tbMotion(x As Integer , y As Integer )  
Declare Sub tbAnimate(animate As GLboolean)  



/' globals '/
Dim shared as  GLuint    tb_lasttime
Dim shared as  GLfloat   tb_lastposition(2)

Dim shared as  GLfloat   tb_angle = 0.0
Dim shared as  GLfloat   tb_axis(2)
Dim shared as  GLfloat   tb_transform(4,4)

Dim shared as  GLuint    tb_width
Dim shared as  GLuint    tb_height

Dim shared as  GLint     tb_button = -1
Dim shared as  GLboolean tb_tracking = GL_FALSE
Dim Shared as  GLboolean tb_animate = GL_TRUE

#Define PI 3.14159265

/' functions '/
Sub ball_tbPointToVector(x As Integer , y As Integer , ancho As Integer , alto As Integer , v() As Single ) 
  Dim As Single  d, a 
  /' project x, y onto a hemi-sphere centered within width, height. '/
  v(0) = (2.0 * x - ancho) / ancho 
  v(1) = (alto - 2.0 * y) / alto 
  d = Sqr(v(0) * v(0) + v(1) * v(1)) 
  v(2) = cos((PI / 2.0) * iif(d < 1.0 , d , 1.0)) 
  a = 1.0 / sqr(v(0) * v(0) + v(1) * v(1) + v(2) * v(2)) 
  v(0) *= a 
  v(1) *= a 
  v(2) *= a 
End Sub

Sub ball_tbStartMotion(x As Integer , y As Integer , button As Integer , timex As Integer ) 
  Assert(tb_button <> -1) 
  tb_tracking = GL_TRUE 
  tb_lasttime = timex 
  ball_tbPointToVector(x, y, tb_width, tb_height, tb_lastposition()) ' rutina encima de esta
End Sub

Sub ball_tbAnimate cdecl() 
  glutPostRedisplay() 
End Sub

Sub ball_tbStopMotion(button As Integer , timex As UInteger ) 
  assert(tb_button <> -1) 
  tb_tracking = GL_FALSE 
  if (timex = tb_lasttime)  And  (tb_animate<>0) Then 
    	glutIdleFunc(@ball_tbAnimate) ' llamada anterior a esta
  Else
    	tb_angle = 0.0 
    	If tb_animate Then glutIdleFunc(0) 
  End If
End Sub

Sub tbAnimate(animate As GLboolean ) 
  tb_animate = animate 
End Sub

Sub tbInit(button As GLuint ) 
  tb_button = button 
  tb_angle = 0.0 
  /' put the identity in the trackball transform '/
  glPushMatrix() 
  glLoadIdentity() 
  glGetFloatv(GL_MODELVIEW_MATRIX, @tb_transform(0,0)) ' (GLfloat *)
  glPopMatrix() 
End Sub

Sub tbMatrix() 
  Assert(tb_button <> -1) 
  glPushMatrix() 
  glLoadIdentity() 
  glRotatef(tb_angle, tb_axis(0), tb_axis(1), tb_axis(2)) 
  glMultMatrixf(@tb_transform(0,0)) ' (GLfloat *)
  glGetFloatv(GL_MODELVIEW_MATRIX, @tb_transform(0,0)) ' (GLfloat *)
  glPopMatrix() 
  glMultMatrixf(@tb_transform(0,0)) ' (GLfloat *)
End Sub

Sub tbReshape(ancho As Integer , alto As Integer ) 
  Assert(tb_button <> -1) 
  tb_width  = ancho 
  tb_height = alto 
End Sub

Sub tbMouse(button As Integer , state As Integer , x As Integer , y As Integer ) 
  Assert(tb_button <> -1) 
  if (state = GLUT_DOWN)  And  (button = tb_button) Then 
   	ball_tbStartMotion(x, y, button, glutGet(GLUT_ELAPSED_TIME)) 
  elseif (state = GLUT_UP)  And  (button = tb_button) Then
		ball_tbStopMotion(button, glutGet(GLUT_ELAPSED_TIME))
  End If
End Sub

Sub tbMotion(x As Integer , y As Integer ) 
  Dim As GLfloat current_position(2), dx, dy, dz 
  assert(tb_button <> -1) 
  If (tb_tracking = GL_FALSE) Then Exit sub 
  
  ball_tbPointToVector(x, y, tb_width, tb_height, current_position()) 
  
  /' calculate the angle to rotate by (directly proportional to the
     length of the mouse movement '/
  dx = current_position(0) - tb_lastposition(0) 
  dy = current_position(1) - tb_lastposition(1) 
  dz = current_position(2) - tb_lastposition(2) 
  tb_angle = 90.0 * sqr(dx * dx + dy * dy + dz * dz) 
  
  /' calculate the axis of rotation (cross product) '/
  tb_axis(0) = tb_lastposition(1) * current_position(2) - _
               tb_lastposition(2) * current_position(1) 
  tb_axis(1) = tb_lastposition(2) * current_position(0) - _
               tb_lastposition(0) * current_position(2) 
  tb_axis(2) = tb_lastposition(0) * current_position(1) - _
               tb_lastposition(1) * current_position(0) 
               
  /' reset for next time '/
  tb_lasttime = glutGet(GLUT_ELAPSED_TIME) ' timer en milisegundos
  tb_lastposition(0) = current_position(0) 
  tb_lastposition(1) = current_position(1) 
  tb_lastposition(2) = current_position(2) 
  
  /' remember to draw new position '/
  glutPostRedisplay() 
End Sub
