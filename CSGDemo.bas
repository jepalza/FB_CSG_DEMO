/'
   Name: GLSAMPLE
   Author: Blaine Hodge
   Description: OpenGL sample
   Copyright: Public domain
   
   conversion FREEBASIC Joseba Epalza (jepalza)
'/


#include "GL/gl.bi"
#include "GL/glut.bi"

#Include "trackball.bas"


' csgOperation types of CSG operations 
Enum csgOperation
    CSG_A=0
    CSG_B,
    CSG_A_OR_B,
    CSG_A_AND_B,
    CSG_A_SUB_B,
    CSG_B_SUB_A
End Enum


#define SEL_BUFFER 32

/' globals '/
Dim Shared as 	GLint ancho_principal
Dim Shared as 	GLint alto_principal
	
Dim Shared as 	GLfloat zoom = 0.0
	
Dim Shared as 	GLboolean cube_picked   = GL_FALSE
Dim Shared as 	GLboolean sphere_picked = GL_FALSE
Dim Shared as 	GLboolean cone_picked   = GL_FALSE
	
Dim Shared as 	GLboolean selection     = GL_FALSE	' rendering to selection buffer 
	
Dim Shared as 	GLint select_buffer(SEL_BUFFER)	' selection buffer 
	
Dim Shared as 	GLfloat cone_x = 0.0
Dim Shared as 	GLfloat cone_y = 0.0
Dim Shared as 	GLfloat cone_z = 0.0
	
Dim Shared as 	GLfloat cube_x = 0.0
Dim Shared as 	GLfloat cube_y = 0.0
Dim Shared as 	GLfloat cube_z = 0.0
	
Dim Shared as 	GLfloat sphere_x = 0.0
Dim Shared as 	GLfloat sphere_y = 0.0
Dim Shared as 	GLfloat sphere_z = 0.0
	
Dim Shared as 	GLint mouse_state = -1
Dim Shared as 	GLint mouse_button = -1
	
Dim Shared as 	csgOperation Op = CSG_A_OR_B



Dim Shared As Integer A
Dim Shared As Integer B

Dim Shared As Integer cono
Dim Shared As integer esfera
Dim Shared As integer cubo




/' sphere()
 *  draw a yellow sphere
 '/
Sub _sphere() 
    glLoadName(2) 
    glPushMatrix() 
    glTranslatef(sphere_x, sphere_y, sphere_z) 
    glColor3f(1.0, 1.0, 0.0) 
    glutSolidSphere(5.0, 16, 16) 
    glPopMatrix() 
End Sub

/' cube()
 *  draw a red cube
 '/
Sub _cube() 
    glLoadName(1) 
    glPushMatrix() 
    glTranslatef(cube_x, cube_y, cube_z) 
    glColor3f(1.0, 0.0, 0.0) 
    glutSolidCube(8.0) 
    glPopMatrix() 
End Sub

/' cone()
 *  draw a green cone
 '/
Sub _cone() 
    glLoadName(3) 
    glPushMatrix() 
    glTranslatef(cone_x, cone_y, cone_z) 
    glColor3f(0.0, 1.0, 0.0) 
    glTranslatef(0.0, 0.0, -6.5) 
    glutSolidCone(4.0, 15.0, 16, 16) 
    glRotatef(180.0, 1.0, 0.0, 0.0) 
    glutSolidCone(4.0, 0.0, 16, 1) 
    glPopMatrix() 
End Sub



Sub AA(A As integer)
	If A=cubo Then _cube()
	If A=esfera Then _sphere()
	If A=cono Then _cone()
End Sub

Sub BB(B As Integer)
	If B=cubo Then _cube()
	If B=esfera Then _sphere()
	If B=cono Then _cone()	
End Sub



/' functions '/
/' one()
 *  draw a single object
 '/
Sub _one(a As Integer Ptr) 
  glEnable(GL_DEPTH_TEST) 
  AA(A)
  glDisable(GL_DEPTH_TEST) 
End Sub

/' or()
 *  boolean A or B (draw wherever A or B)
 *  algorithm: simple, just draw both with depth test enabled
 '/
Sub _or(a As Integer ptr, b As Integer Ptr) 
    glPushAttrib(GL_ALL_ATTRIB_BITS)  /' TODO - should just push depth '/
    glEnable(GL_DEPTH_TEST) 
    AA(A)
    BB(B) 
    glPopAttrib() 
End Sub

/' inside()
 *  sets stencil buffer to show the part of A
 *  (front or back face according to ´face´)
 *  that is inside of B.
 '/
Sub inside(a As Integer ptr, b As Integer Ptr, face As GLenum , test As GLenum ) 
    /' draw A into depth buffer, but not into color buffer '/
    glEnable(GL_DEPTH_TEST) 
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE) 
    glCullFace(face) 
    AA(A) 
    
    /' use stencil buffer to find the parts of A that are inside of B
     * by first incrementing the stencil buffer wherever B´s front faces
     * are...
     '/
    glDepthMask(GL_FALSE) 
    glEnable(GL_STENCIL_TEST) 
    glStencilFunc(GL_ALWAYS, 0, 0) 
    glStencilOp(GL_KEEP, GL_KEEP, GL_INCR) 
    glCullFace(GL_BACK) 
    BB(B) 
    
    /' ...then decrement the stencil buffer wherever B´s back faces are '/
    glStencilOp(GL_KEEP, GL_KEEP, GL_DECR) 
    glCullFace(GL_FRONT) 
    BB(B) 
    
    /' now draw the part of A that is inside of B '/
    glDepthMask(GL_TRUE) 
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE) 
    glStencilFunc(test, 0, 1) 
    glDisable(GL_DEPTH_TEST) 
    glCullFace(face) 
    AA(A) 
    
    /' reset stencil test '/
    glDisable(GL_STENCIL_TEST) 
End Sub

/' fixup()
 *  fixes up the depth buffer with A´s depth values
 '/
Sub fixup(a As Integer Ptr) 
	
    /' fix up the depth buffer '/
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE) 
    glEnable(GL_DEPTH_TEST) 
    glDisable(GL_STENCIL_TEST) 
    glDepthFunc(GL_ALWAYS) 
    AA(A) 
    
    /' reset depth func '/
    glDepthFunc(GL_LESS) 
End Sub

/' and()
 *  boolean A and B (draw wherever A intersects B)
 *  algorithm: find where A is inside B, then find where
 *             B is inside A
 '/
Sub _and(a As Integer , b As Integer ) 
    inside(a, b, GL_BACK, GL_NOTEQUAL) 
    fixup(b) ' desactivando es mas rapido calculando, pero salen muy malos resultados en los cortes
    inside(b, a, GL_BACK, GL_NOTEQUAL) 
End Sub

/'
 * sub()
 *  boolean A subtract B (draw wherever A is and B is NOT)
 *  algorithm: find where a is inside B, then find where
 *             the BACK faces of B are NOT in A
 '/
Sub _sub(a As Integer ptr, b As Integer Ptr) 
    inside(a, b, GL_FRONT, GL_NOTEQUAL) 
    fixup(b) ' desactivando es mas rapido calculando, pero salen muy malos resultados en los cortes
    inside(b, a, GL_BACK, GL_EQUAL) 
End Sub



Sub init () 
    Dim As GLfloat lightposition(3) = { -3.0, 3.0, 3.0, 0.0 } 
    
    ' rutina en "trackball.bas"
    tbInit(GLUT_MIDDLE_BUTTON) 
    
    glSelectBuffer(SEL_BUFFER, @select_buffer(0)) 
    glDepthFunc(GL_LESS) 
    glEnable(GL_DEPTH_TEST) 
    glEnable(GL_LIGHT0) 
    glEnable(GL_LIGHTING) 
    glLightfv(GL_LIGHT0, GL_POSITION, @lightposition(0)) 
    glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, GL_TRUE) 
    glEnable(GL_COLOR_MATERIAL) 
    glEnable(GL_CULL_FACE) 
    glClearColor(0.0, 0.0, 1.0, 0.0) 
End Sub

Sub gl_reshape cdecl(ByVal ancho As Integer , ByVal alto As Integer ) 
    ancho_principal = ancho 
    alto_principal= alto 
    
    ' rutina en "trackball.bas"
    tbReshape(ancho, alto) 
    
    glViewport(0, 0, ancho, alto) 
    glMatrixMode(GL_PROJECTION) 
    glLoadIdentity() 
    glFrustum(-3.0, 3.0, -3.0, 3.0, 64, 256) 
    glMatrixMode(GL_MODELVIEW) 
    glLoadIdentity() 
    glTranslatef(0.0, 0.0, -200.0 + zoom) 
End Sub

Sub gl_display cdecl() 
  glClear(GL_COLOR_BUFFER_BIT  Or  GL_DEPTH_BUFFER_BIT  Or  GL_STENCIL_BUFFER_BIT) 
  glPushMatrix() 
  
  ' rutina en "trackball.bas"
  tbMatrix() 
  
  Select Case Op 
  	
	 Case CSG_A 
	    _one(A)
	     
	 Case CSG_B 
	    _one(B) 
	     
	 Case CSG_A_OR_B 
	    _or(A, B) 
	     
	 Case CSG_A_AND_B 
	    _and(A, B) 
	     
	 Case CSG_A_SUB_B 
	    _sub(A, B) 
	     
	 Case CSG_B_SUB_A 
	    _sub(B, A) 
	     
  End select
  
  glPopMatrix() 
  if selection=0 Then glutSwapBuffers() 
  
End Sub

Function mouse_pick (x As Integer , y As Integer ) As Integer 
  Dim As GLint i, hits, num_names, picked 
  Dim As GLint Ptr p 
  Dim As GLboolean save 
  Dim As GLint depth = -1 
  Dim As GLint viewport(3) 
  
  /' get the current viewport parameters '/
  glGetIntegerv(GL_VIEWPORT, @viewport(0)) 
  
  /' set the render mode to selection '/
  glRenderMode(GL_SELECT) 
  selection = GL_TRUE 
  glInitNames() 
  glPushName(0) 
  
  /' setup a picking matrix and render into selection buffer '/
  glMatrixMode(GL_PROJECTION) 
  glPushMatrix() 
  
  glLoadIdentity() 
  gluPickMatrix(x, viewport(3) - y, 5.0, 5.0, @viewport(0)) 
  glFrustum(-3.0, 3.0, -3.0, 3.0, 64, 256) 
  
  glMatrixMode(GL_MODELVIEW) 
  glLoadIdentity() 
  glTranslatef(0.0, 0.0, -200.0 + zoom) 
  glClear(GL_COLOR_BUFFER_BIT  Or  GL_DEPTH_BUFFER_BIT  Or  GL_STENCIL_BUFFER_BIT) 
  
  glPushMatrix() 
  
  ' rutina en "trackball.bas"
  tbMatrix() 
  
  _or(A, B) 
  glPopMatrix() 
  
  glMatrixMode(GL_PROJECTION) 
  glPopMatrix() 
  glMatrixMode(GL_MODELVIEW) 
  
  hits = glRenderMode(GL_RENDER) 
  
  selection = GL_FALSE 
  
  p = @select_buffer(0) 
  picked = 0 
  
  for  i = 0 To hits-1
    save = GL_FALSE
    num_names = *p			/' number of names in this hit '/
    p+=1 
    
    if (*p <= depth) Then 			/' check the 1st depth value '/
      depth = *p 
      save = GL_TRUE 
    End If
    p+=1 
    
    if (*p <= depth) Then 			/' check the 2nd depth value '/
      depth = *p 
      save = GL_TRUE 
    End If
    p+=1 
    
    if (save) Then picked = *p 
    p += num_names			/' skip over the rest of the names '/
  Next
  
  return picked 
End Function

' lectura teclas llamado desde GL (en este ejemplo, X e Y no se usan, siempre 0)
Sub gl_keyboard cdecl(ByVal key As uByte ,ByVal x As Integer ,ByVal y As Integer ) 

	Dim As String keys=Chr(key)

    Select Case (keys) 
    	Case "c" 
			if(A = @_cube()) And (B = @_sphere() ) Then 
			    A = @_sphere() 
			    B = @_cone() 
			ElseIf (A = @_sphere() ) And (B = @_cone()) Then  
			    A = @_cone() 
			    B = @_cube() 
			Else  /' if(A == cone && B = cube) '/
			    A = @_cube() 
			    B = @_sphere() 
			End If
	 
    	Case "a" 
			Op = CSG_A 
	 
    	case "b" 
			Op = CSG_B 
	 
    	case "|" 
			Op = CSG_A_OR_B 
	 
    	case "&" 
			Op = CSG_A_AND_B 
	 
    	Case "-" 
			Op = CSG_A_SUB_B 
	 
    	Case "_" 
			Op = CSG_B_SUB_A 
	 
    	Case "z" 
			zoom -= 6.0 
			gl_reshape(ancho_principal, alto_principal) 
	 
    	case "Z" 
			zoom += 6.0 
			gl_reshape(ancho_principal, alto_principal) 
	 
    	Case Chr(27) 
	  		End 
	 
    	Case "\r" 
	 
    	Case Else 
			Exit Sub 
    End Select
    
    glutPostRedisplay() 
End Sub

Sub gl_mouse Cdecl (ByVal button As Integer ,byval state As Integer ,byval x As Integer ,byval y As Integer ) 
  mouse_state = state 
  mouse_button = button 
  
  ' rutina en "trackball.bas"
  tbMouse(button, state, x, y)
  
  if (button = GLUT_LEFT_BUTTON) Then 
          
    Select Case  (mouse_pick(x, y)) 
	
    	case 1 
	      cube_picked = GL_TRUE 
	      sphere_picked = GL_FALSE 
	      cone_picked = GL_FALSE 
	       
    	Case 2 
	      sphere_picked = GL_TRUE 
	      cube_picked = GL_FALSE 
	      cone_picked = GL_FALSE 
	       
    	case 3 
	      cone_picked = GL_TRUE 
	      sphere_picked = GL_FALSE 
	      cube_picked = GL_FALSE 
	       
    	Case else 
	      sphere_picked = GL_FALSE 
	      cube_picked = GL_FALSE 
	      cone_picked = GL_FALSE 
       
    End Select
  End If
  
  glutPostRedisplay() 
End Sub

Sub cross(u() As GLfloat , v() As GLfloat , n() As GLfloat ) 
  /' compute the cross product (u x v for right-handed (ccw)) '/
  n(0) = u(1) * v(2) - u(2) * v(1) 
  n(1) = u(2) * v(0) - u(0) * v(2) 
  n(2) = u(0) * v(1) - u(1) * v(0) 
End Sub

Function normalize(n() As GLfloat ) As Single 
  Dim As GLfloat l 
  /' normalize '/
  l = sqr(n(0) * n(0) + n(1) * n(1) + n(2) * n(2)) 
  n(0) /= l 
  n(1) /= l 
  n(2) /= l 
  return l 
End Function

Sub gl_motion cdecl(ByVal x As Integer ,byval y As Integer ) 
  Dim As GLdouble model(4*4) 
  Dim As GLdouble proj(4*4) 
  Dim As GLint vista(4) 
  Dim As GLdouble pan_x, pan_y, pan_z 
  
  ' rutina en "trackball.bas"
  tbMotion(x, y) 
  
  If (mouse_state = GLUT_DOWN) And (mouse_button = GLUT_LEFT_BUTTON) Then 
    glGetDoublev(GL_MODELVIEW_MATRIX, @model(0))
    glGetDoublev(GL_PROJECTION_MATRIX, @proj(0))  
    glGetIntegerv(GL_VIEWPORT, @vista(0)) 
    
    gluProject(CDbl(x), CDbl(y), 0.0, _
		 @model(0), @proj(0), @vista(0), _
		  @pan_x,  @pan_y,  @pan_z) 
		  
    gluUnProject(CDbl(x), CDbl(y), pan_z, _
		 @model(0), @proj(0), @vista(0), _
		  @pan_x,  @pan_y,  @pan_z) 
		  
    pan_y = -pan_y 
    
    if (sphere_picked) Then  
      sphere_x = pan_x 
      sphere_y = pan_y 
      sphere_z = pan_z 
    ElseIf (cone_picked) Then  
      cone_x = pan_x 
      cone_y = pan_y 
      cone_z = pan_z 
    ElseIf (cube_picked) Then  
      cube_x = pan_x 
      cube_y = pan_y 
      cube_z = pan_z 
    End If
    
  End If
  
  glutPostRedisplay() 
End Sub

Sub gl_menu cdecl(ByVal item As Integer ) 
    gl_keyboard( CUByte(item), 0, 0) 
End Sub


    Dim As Integer ops, zoom_menu 
    
    glutInit( 0, "" ) 
    
    glutInitDisplayMode(GLUT_RGB  Or  GLUT_DOUBLE  Or  GLUT_DEPTH  Or  GLUT_STENCIL) 
    glutCreateWindow("CSG Operations Demo") 
    glutDisplayFunc(@gl_display) 
    glutReshapeFunc(@gl_reshape) 
    glutKeyboardFunc(@gl_keyboard) 
    glutMouseFunc(@gl_mouse) 
    glutMotionFunc(@gl_motion) 
    
    
    ops = glutCreateMenu(@gl_menu) 
    glutAddMenuEntry("A only          (a)", Asc("a") )
    glutAddMenuEntry("B only          (b)", Asc("b") )
    glutAddMenuEntry("A or B          (|)", Asc("|") )
    glutAddMenuEntry("A and B         (&)", Asc("&") )
    glutAddMenuEntry("A sub B         (-)", Asc("-") )
    glutAddMenuEntry("B sub A         (_)", Asc("_") )
    
    
    zoom_menu = glutCreateMenu(@gl_menu) 
    glutAddMenuEntry("Zoom decrease   (z)", Asc("z") )
    glutAddMenuEntry("Zoom increase   (Z)", Asc("Z") )
    
    glutCreateMenu(@gl_menu) 
    glutAddMenuEntry("CSG Operations Demo", 0 )
    glutAddMenuEntry("                   ",0 )
    glutAddSubMenu(  "Operations         ", ops) 
    glutAddSubMenu(  "Zoom               ", zoom_menu)
    glutAddMenuEntry("                   ", 0 )
    glutAddMenuEntry("Change shapes   (c)", Asc("c") )
    glutAddMenuEntry("                   ", 0 )
    glutAddMenuEntry("Quit          (Esc)", 27 ) '27=ESC
    glutAttachMenu(GLUT_RIGHT_BUTTON) 
    
    esfera=@_sphere()
    cubo=@_cube()
    cono=@_cone()
    
    init() 
    A = cubo
    B = esfera

    glutMainLoop() 
