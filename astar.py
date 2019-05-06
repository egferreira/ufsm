
# !usr/bin/env python3
"""
 Emilio Ferreira
 2019/1 - UFSM

 Trabalho 2 de Inteligência Artificial
 Data de Entrega 06/05/19
 Tema : A*
 Requisitos : Prametrizavel
			  Orientado a objetos
"""


import sys
import numpy as np
import time
import random
import pandas

# VARIAVEIS GLOBAIS E DEFINES
globals()['N_DIMENSOES'] = 3
globals()['DEFAULT'] = 3
globals()['DEBUG_CONT'] = 0

    """ Classe que representa um Nodo com uma vizinhança e parametros de objetivo e de inicio
    """
class Node:

	""" Inicialização do nodo e suas variaveis """
    def __init__(self, id):
        
        self.vizinho_acima    = None 
        self.vizinho_direita  = None
        self.vizinho_abaixo   = None
        self.vizinho_esquerda = None
        self.vizinho_frente   = None
        self.vizinho_atras    = None
        self.start    = False # Utilizado para o nodo saber se é start ou não
        self.objetivo = False # Utilizado para o nodo saber se é objetivo ou não
        self.blocked  = False # Representa se o cubo
        self.gScore = np.inf # Seta o g Score como infinito
        self.fScore = np.inf # Seta o f Score como infinito
        self.anterior = None # Caminho para ser mostrado

        if (len(id) == N_DIMENSOES): # Verifica o numero correto de dimensoes
            self.id = (id)
        else: # Erro na passagem de parametros
            print(" Parametro passado em Node não é correto."\
                    + " Esperado : tupla de {} parametros".format(N_DIMENSOES) + " Finalizando o programa ")
            quit() # Para a execução do programa
	
	""" Metodo que seta o Node como inicio """
    def set_start(self):    
        self.start = True
		
	""" Metodo que seta um nodo como objetivo """
    def set_objetivo(self):
        self.objetivo = True
	""" Metodo que bloqueia o nodo """
    def set_blocked(self):   
        self.blocked = True

	""" Metodo que seta todos os vizinhos de um Node """
    def set_vizinhos(self, acima, direita, abaixo, esquerda, frente, atras):
        self.set_vizinho_acima(acima)
        self.set_vizinho_direita(direita)
        self.set_vizinho_abaixo(abaixo)
        self.set_vizinho_esquerda(esquerda)
        self.set_vizinho_frente(frente)
        self.set_vizinho_atras(atras)

	""" Metodo que seta o vizinho em frente do Node """
    def set_vizinho_frente(self, vizinho):    
        self.vizinho_frente = tuple(vizinho)

	""" Metodo que seta o vizinho em atras do Node """
    def set_vizinho_atras(self, vizinho):
        self.vizinho_atras = tuple(vizinho)
		
	""" Metodo que seta o vizinho acima do Node """
    def set_vizinho_acima(self, vizinho):  
        self.vizinho_acima = tuple(vizinho)
	
	""" Metodo que seta o vizinho a direita do Node """
    def set_vizinho_direita(self, vizinho):    
        self.vizinho_direita = tuple(vizinho)

	""" Metodo que seta o vizinho abaixo do Node """
    def set_vizinho_abaixo(self, vizinho):    
        self.vizinho_abaixo = tuple(vizinho)
		
    """ Metodo que seta o vizinho a esquerda do Node """
    def set_vizinho_esquerda(self, vizinho):  
        self.vizinho_esquerda = tuple(vizinho)

    """ Metodo que retorna toda a vizinhança de um Node 
	"""
    def get_vizinhos(self):    
        return (self.vizinho_acima, self.vizinho_direita,
                self.vizinho_abaixo, self.vizinho_esquerda,
                self.vizinho_frente, self.vizinho_atras)

	
    """ Metodo que mostra todos os ID's da vizinhança de um node 
	"""
    def print_vizinhos(self):
        print("  Acima  | Abaixo  | Direita | Equerda |  Frente | Atras  ")
        print(self.vizinho_acima.id,    end = " ") if self.vizinho_acima    != None else print("   None  ", end =" ")
        print(self.vizinho_abaixo.id,   end = " ") if self.vizinho_abaixo   != None else print("   None  ", end =" ")
        print(self.vizinho_direita.id,  end = " ") if self.vizinho_direita  != None else print("   None  ", end =" ")
        print(self.vizinho_esquerda.id, end = " ") if self.vizinho_esquerda != None else print("   None  ", end =" ")
        print(self.vizinho_frente.id,   end = " ") if self.vizinho_frente   != None else print("   None  ", end =" ")
        print(self.vizinho_atras.id) if self.vizinho_atras != None else print("   None  ")
	
	""" Classe que representa um cubo, NxNxN, seus metodos para setar um objetivo/inicio, gerar bloqueios,
        Instanciar vizinhança e gerar o cubo
    """
	
	
	
class Cubo:
    
	
   """"Inicialização do cubo e suas variaveis 
   cubo - Dicionário de Nodos
   start - Inicio setado para o cubo
   objetivo - Objetivo setado para o cubo
   """
    def __init__(self):
        
        self.cubo = {}
        self.dimensao_X = None
        self.dimensao_Y = None
        self.dimensao_Z = None
        self.start = None
        self.objetivo = None
        self.numero_nodos = None
        self.numero_bloqueados = None
        self.porcentagem_bloqueada = None

   """ Metodo que gera um cubo com N dimensoes e liga os nodos de acordo
   Seta as vizinhanças para os nodos alocados dentro do cubo
   """
    def generate_cubo(self, dimensao):
        
        self.numero_nodos = 0
        self.numero_bloqueados = 0
        self.porcentagem_bloqueada = 0

        try: # Controle de erros
            self.dimensao_X = int(dimensao)
            self.dimensao_Y = int(dimensao)
            self.dimensao_Z = int(dimensao)
        except: 
            print(" Dimensões erradas, setadas para default 3x3x3")
            self.generate_cubo(DEFAULT)
            return

        for i in range(self.dimensao_X):
            for j in range(self.dimensao_Y):
                for k in range(self.dimensao_Z):
                    self.cubo[(i, j, k)] = Node( (i, j, k) )
                    self.numero_nodos += 1
                    if k != 0 : # Condições de contorno, altura igual a zero
                        self.cubo[(i, j, k)].vizinho_abaixo = self.cubo[(i, j, k-1)] # Seta vizinho Abaixo
                        self.cubo[(i, j, k-1)].vizinho_acima = self.cubo[(i, j, k)]  # Seta vizinho Acima

                    if j != 0 : # COndicções de contorno, profuntidade igual a zero
                        self.cubo[(i, j, k)].vizinho_atras = self.cubo[(i, j-1, k)]  # Seta vizinho Atras
                        self.cubo[(i, j-1, k)].vizinho_frente = self.cubo[(i, j, k)] # Seta vizinho a Frente

                    if i != 0 : # Condições de contornor, posição igual a zero
                        self.cubo[(i, j, k)].vizinho_esquerda = self.cubo[(i-1, j, k)] # Seta vizinho a Esquerda
                        self.cubo[(i-1, j, k)].vizinho_direita = self.cubo[(i, j, k)]  # Seta vizinho a Direita

   """ Metodo que gera os nodos bloqueados no cubo baseando-se na porcentagem desejada
   Em casos de numeros não inteiros, o metodo utiliza o menor valor inteiro
   """
    def generate_blocked(self, porcentagem):

        self.porcentagem_bloqueada = porcentagem/100  # Porcentagem de bloqueados
        if(self.porcentagem_bloqueada == 100): # Verifica se existe soluçõa e evita loop infinitos
            print(" Todos os nodos Bloqueados, não é possível executar")
            quit() # Finaliza a execução do programa
        self.numero_bloqueados = int(self.porcentagem_bloqueada * self.numero_nodos)
        random_index = random.choice(list(self.cubo))
        for i in range(self.numero_bloqueados): # Enquanto o numero de bloqueados for inferior a o desejado
            # Caso o indice gerado já esteja bloqueado continua gerando até encontrar outro não bloqueado
            while (self.cubo[random_index].blocked == True):
                random_index = random.choice(list(self.cubo))
            self.cubo[random_index].set_blocked()

   """ Metodo que seta o start para algum nodo não bloqueado do cubo
   Inicio pode ser passado para o método, caso não for, o mesmo irá gerar um inicio aleatoriamente
   Garante que o nodo setado como start não esteja bloqueado ou seja objetivo
   """
    def set_start(self, start_usuario = None):
        
        if start_usuario is None or len(start_usuario) != N_DIMENSOES:
            #print(" Inicio não especificado ou parametros errado. Criação aleatória de inicio ")
            random_index = random.choice(list(self.cubo))
            # Garante a criação de um começo não bloqueado
            while ( self.cubo[random_index].blocked == True):
                random_index = random.choice(list(self.cubo))
            self.cubo[random_index].set_start()
            self.start = self.cubo[random_index]
        else: # Parametros passados pelo Usuario
            if self.cubo[start_usuario].blocked == True or self.cubo[start_usuario].objetivo == True:
                return self.set_start()
            self.cubo[start_usuario].set_start()
            self.start = self.cubo[start_usuario]

   """ Metodo que gera o objetivo dentro de um cubo
   Objetivo pode ser passado para o método, caso não seja irá criar aleatóriamente um objetivo para o cubo
   Garante que o objetivo não seja o Nodo de Start e não esteja bloqueado
   """
    def set_objetivo(self, objetivo_usuario = None ):
        
        if self.numero_nodos - 2 < self.numero_bloqueados: # Garante que existam mais de 2 nodos livres
            print(" Sem nodos livres o suficiente, não é possível executar")
            quit() # Finaliza a execução do programa
        if objetivo_usuario is None or len(objetivo_usuario) != N_DIMENSOES:
            #print(" Objetivo não especificado ou parametros errados. Criação aleatória de objetivo ")
            random_index = random.choice(list(self.cubo))
            while ( self.cubo[random_index].blocked == True or self.cubo[random_index].start == True):
                random_index = random.choice(list(self.cubo))
            self.cubo[random_index].set_objetivo()
            self.objetivo = self.cubo[random_index]
        else: # Parametros passados pelo usuário
            if (self.cubo[objetivo_usuario].blocked == True or self.cubo[objetivo_usuario].start == True):
                return self.set_objetivo()
            self.cubo[objetivo_usuario].set_objetivo()
            self.objetivo = self.cubo[objetivo_usuario]
	
   """ Metodo que calcula a distancia euclidiana entre dois pontos tridimensionais ]
   Realiza o a raiz do módulo da diferenca entre as coordenadas dos Nodos
   Retorna Distanca(float)
   Utiliza Numpy
   Não possui controle de erros, caso os parametros sejam passados errados, irá gerar erro
   """
    def get_distance(self, atual, objetivo):
        
        distancia = ((objetivo.id[0] - atual.id[0])**2 +
                     (objetivo.id[1] - atual.id[1])**2 +
                     (objetivo.id[2] - atual.id[2])**2 )
        distancia = np.sqrt(distancia)
        return distancia

   """ Retorna o inicio do Cubo 
   Retorna o nodo setado como start
   Não possui controle de erros, se for chamada antes do incio ser setado, irá gerar erro
   """
    def get_start(self):
        return self.start

   """ Retorna o objetivo do Cubo 
   Função com retorno, retorna tipo Node
   Caso objetivo não esteja setado não retorna nada
   """
    def get_objetivo(self):
        if self.objetivo == None:
            print(" Cubo sem Objetivo ")
        return self.objetivo

   """ Mostra o objetivo do cubo 
   Printa a posição setada como objetivo do cubo
   Não possui controle de erros, caso o objetivo não esteja setado, irá gerar erro
   """
    def print_objetivo(self):
        print(" OBJETIVO: {}".format( self.objetivo.id))

   """ Mostra o inicio "
   " Print no nodo setada como inicio do cubo"
   " Não possui controle de erros, caso o inicio não for setado, irá gerar erro
   """
    def print_start(self):
        print(" START:    {}".format( self.start.id))

   """ Mostra todo o cubo 
   Mostra todos os nos e mostra bloqueados, inicio, objetivo
   """
    def print_cubo(self):
        for i in self.cubo:
            print(self.cubo[i].id, end = " ")
            if self.cubo[i].blocked == True :
                print (" Bloqueado")
            else:
                if self.cubo[i].start == True :
                    print( " ========================= Inicio")
                elif self.cubo[i].objetivo == True:
                    print( " ========================= Objetivo")
                else:
                    print(" Livre")

   """ Mostra o tamanho do cubo "
   Chamada recursiva para print "
   """
	def print_tamanho(self):
		# Mostr ao cubo recursivamente
        print(" Cubo com {} Nodos".format(self.numero_nodos))

		
""" CLasse de implementação do algorítmo A* """
class A_STAR:
    
	
   """ Inicialização das variaveis para o método A* """
    def __init__(self):
        
        self.cubo = None
        self.atual = None
        self.fechados = None
        self.abertos = None
        self.caminho = None
	
   """ Implementação do Método A* """
    def find_a_star(self, cubo):
     
        self.cubo = cubo
        self.atual = cubo.get_start()
        self.fechados = []
        self.abertos = []
        self.caminho = []

        self.abertos.append(self.atual)
        self.atual.gScore = 0 # gScore do Start
        self.atual.fScore = self.cubo.get_distance(self.atual, cubo.objetivo)# gScore do Start

        while( len(self.abertos)!= 0): # Enquanto existir nós abertos
            fScore_menor_dos_vizinhos = np.inf
            for i in self.abertos: # Aberto com o menor valor de fScore
                if i.fScore < fScore_menor_dos_vizinhos and i != self.atual:
                    fScore_menor_dos_vizinhos= i.fScore
                    self.atual = i

            if self.atual == cubo.objetivo:
                #print(self.atual.id, cubo.objetivo.id)
                #self.print_caminho(self.atual)
                self.custo = len(self.get_caminho(self.atual))
                return self.custo

            self.abertos.remove(self.atual) # Remove o atual dos abertos
            self.fechados.append(self.atual) # Coloca o atual nos fechados
            vizinhos = self.atual.get_vizinhos()
            for vizinho in vizinhos:
                if vizinho in self.fechados: continue # Vizinho já foi visitado
                if vizinho == None: continue # Vizinho não é caminho
                if vizinho.blocked == True: continue #Vizinho fechado

                # Distancia do início até um vizinho
                gScore_tentativa = self.atual.gScore + self.cubo.get_distance(self.atual, vizinho)

                if vizinho not in self.abertos: # Adiciona nos abertos
                    self.abertos.append(vizinho)
                elif gScore_tentativa >= vizinho.gScore:
                    continue
                vizinho.anterior = self.atual # Atualiza o melhor caminho
                vizinho.gScore = gScore_tentativa
                vizinho.fScore = vizinho.gScore + self.cubo.get_distance(vizinho, cubo.objetivo)
        return None # Caminho não encontrado

	""" Metodo que retorna o caminho o caminho """
    def get_caminho(self, node):
        node__ = node
        if node__.anterior == None:
            return
        self.get_caminho( node__.anterior) # Chamada da propria função recursivamente
        self.caminho.append(node__)
        return self.caminho

	""" Metodo que mostra o caminho """	
    def print_caminho(self, node):    
        if node.anterior == None:
            return
        self.print_caminho( node.anterior)
        self.caminho.append(node)
        print (" {} ".format(node.id))

def main():
    tempo_de_simulaca0 = 60*10 # 30 minutos de simulação
    t_inicio = time.time()
    t_end = t_inicio + tempo_de_simulaca0

	# Variaveis de simulaçao
    distancias = []
    tempos = []
    inicios = []
    finais = []
    contador = 0
    while time.time() < t_end :
        cubo_main = Cubo()
        cubo_main.generate_cubo(5) # Cubo com o tamanho 10x10x10
        cubo_main.generate_blocked(33) # 33 % de bloqueio

        a = A_STAR()
        cubo_main.set_start() # Seta inicio aleatóriamente
        cubo_main.set_objetivo() # Seta objetivo aleatóriamente

        start = time.perf_counter()  # Timer
        custo = a.find_a_star(cubo_main)
        end = time.perf_counter()     # Timer

        if custo == None: continue # Caminho não encontrado
        tempo = end-start
        #print("Custo : {}".format(custo))
        #print("Tempo : {}".format(tempo))
        distancias.append(custo)
        tempos.append(tempo)
        inicios.append(cubo_main.start.id)
        finais.append(cubo_main.objetivo.id)

		# Interface para mostrar a simulacao rodando
        print("Estimado: {0}   Atual :   {1}".format(t_end-t_inicio, time.time()-t_inicio))

	# Salvamento dos resultados em uma planilha
    df = pandas.DataFrame( {'Inicio': inicios, 'Final': finais, 'Distancia': distancias,'Tempos' : tempos })
    writer = pandas.ExcelWriter('final2_Size5_bloqued33.xlsx', engine = "xlsxwriter")
    df.to_excel(writer, sheet_name ="final1")
    writer.save()

if __name__ == "__main__":
    main()
