
"""
 Emilio Ferreira
 2019/1 - UFSM

 Trabalho 2 de Inteligência Artificial
 Data de Entrega
 Tema :
 Requisitos :
"""


import sys
import numpy as np
import time
import random
# VARIAVEIS GLOBAIS E DEFINES
globals()['N_DIMENSOES'] = 3
globals()['DEFAULT'] = 3

class Node:
    """ Classe que representa um Nodo com uma vizinhança e parametros de objetivo e de inicio
    """


    def __init__(self, id):
        " Inicialização do cubo e suas variaveis"
        self.vizinho_acima    = None
        self.vizinho_direita  = None
        self.vizinho_abaixo   = None
        self.vizinho_esquerda = None
        self.vizinho_frente   = None
        self.vizinho_atras    = None
        self.start    = False
        self.objetivo = False
        self.blocked  = False
        self.gScore = np.inf # Seta o g Score como infinito
        self.fScore = np.inf # Seta o f Score como infinito

        if (len(id) == N_DIMENSOES): # Verifica o numero correto de dimensoes
            self.id = (id)
        else:
            print(" Parametro passado em Node não é correto."\
                    + " Esperado : tupla de {} parametros".format(N_DIMENSOES) + " Finalizando o programa ")
            quit() # Para a execução do programa

    def set_start(self):
        " Metodo que seta o Node como inicio "
        self.start = True

    def set_objetivo(self):
        " Metodo que seta um nodo como objetivo "
        self.objetivo = True

    def set_blocked(self):
        " Metodo que bloqueia o nodo"
        self.blocked = True

    def set_vizinhos(self, acima, direita, abaixo, esquerda, frente, atras):
        " Metodo que seta todos os vizinhos de um Node "
        self.set_vizinho_acima(acima)
        self.set_vizinho_direita(direita)
        self.set_vizinho_abaixo(abaixo)
        self.set_vizinho_esquerda(esquerda)
        self.set_vizinho_frente(frente)
        self.set_vizinho_atras(atras)

    def set_vizinho_frente(self, vizinho):
        " Metodo que seta o vizinho em frente do Node "
        self.vizinho_frente = tuple(vizinho)

    def set_vizinho_atras(self, vizinho):
        " Metodo que seta o vizinho em atras do Node "
        self.vizinho_atras = tuple(vizinho)

    def set_vizinho_acima(self, vizinho):
        " Metodo que seta o vizinho acima do Node "
        self.vizinho_acima = tuple(vizinho)

    def set_vizinho_direita(self, vizinho):
        " Metodo que seta o vizinho a direita do Node "
        self.vizinho_direita = tuple(vizinho)

    def set_vizinho_abaixo(self, vizinho):
        " Metodo que seta o vizinho abaixo do Node "
        self.vizinho_abaixo = tuple(vizinho)

    def set_vizinho_esquerda(self, vizinho):
        " Metodo que seta o vizinho a esquerda do Node "
        self.vizinho_esquerda = tuple(vizinho)

    def get_vizinhos(self):
        " Metodo que retorna toda a vizinhança de um Node "
        return (self.vizinho_acima, self.vizinho_direita,
                self.vizinho_abaixo, self.vizinho_esquerda,
                self.vizinho_frente, self.vizinho_atras)

    def print_vizinhos(self):
        " Metodo que mostra todos os ID's da vizinhança de um node"
        print("  Acima  | Abaixo  | Direita | Equerda |  Frente | Atras  ")
        print(self.vizinho_acima.id,    end = " ") if self.vizinho_acima    != None else print("   None  ", end =" ")
        print(self.vizinho_abaixo.id,   end = " ") if self.vizinho_abaixo   != None else print("   None  ", end =" ")
        print(self.vizinho_direita.id,  end = " ") if self.vizinho_direita  != None else print("   None  ", end =" ")
        print(self.vizinho_esquerda.id, end = " ") if self.vizinho_esquerda != None else print("   None  ", end =" ")
        print(self.vizinho_frente.id,   end = " ") if self.vizinho_frente   != None else print("   None  ", end =" ")
        print(self.vizinho_atras.id) if self.vizinho_atras != None else print("   None  ")

class Cubo:
    """ Classe que representa um cubo, NxNxN, seus metodos para setar um objetivo/inicio, gerar bloqueios,
        Instanciar vizinhança e gerar o cubo
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

    def generate_cubo(self, dimensao):
        """ Metodo que gera um cubo com N dimensoes e liga os nodos de acordo"""
        self.numero_nodos = 0
        self.numero_bloqueados = 0
        self.porcentagem_bloqueada = 0

        try:
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
                        self.cubo[(i, j, k-1)].vizinho_acima = self.cubo[(i, j, k)] # Seta vizinho Acima

                    if j != 0 : # COndicções de contorno, profuntidade igual a zero
                        self.cubo[(i, j, k)].vizinho_atras = self.cubo[(i, j-1, k)] # Seta vizinho Atras
                        self.cubo[(i, j-1, k)].vizinho_frente = self.cubo[(i, j, k)] # Seta vizinho a Frente

                    if i != 0 : # Condições de contornor, posição igual a zero
                        self.cubo[(i, j, k)].vizinho_esquerda = self.cubo[(i-1, j, k)] # Seta vizinho a Esquerda
                        self.cubo[(i-1, j, k)].vizinho_direita = self.cubo[(i, j, k)] # Seta vizinho a Direita

    def generate_blocked(self, porcentagem):
        """ Metodo que gera os nodos bloqueados no cubo baseando-se na porcentagem desejada
            Em casos de numeros não inteiros, o metodo utiliza o menor valor inteiro
        """
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

    def set_start(self, start_usuario = None):
        " Metodo que seta o start para algum nodo não bloqueado do cubo"
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

    def set_objetivo(self, objetivo_usuario = None ):
        " Metodo que gera o objetivo dentro de um cubo"
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

    def get_distance(self, atual, objetivo):
        " Metodo que calcula a distancia euclidiana entre dois pontos tridimensionais"
        distancia = ((objetivo.id[0] - atual.id[0])**2 +
                     (objetivo.id[1] - atual.id[1])**2 +
                     (objetivo.id[2] - atual.id[2])**2 )
        distancia = np.sqrt(distancia)
        return distancia

    def get_start(self):
        " Retorna o inicio do Cubo"
        return self.start

    def get_objetivo(self):
        if self.objetivo == None:
            print(" Cubo sem Objetivo ")
        return self.objetivo

    def print_objetivo(self):
        print(" OBJETIVO: {}".format( self.objetivo.id))

    def print_start(self):
        print(" START:    {}".format( self.start.id))

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

    def print_tamanho(self):
        print(" Cubo com {} Nodos".format(self.numero_nodos))

class A_STAR:
    """ CLasse de implementação do algorítmo A*
    """
    def __init__(self):
        self.cubo = None
        self.atual = None
        self.fechados = None
        self.abertos = None
        self.caminho = None

    def find_a_star(self, cubo):
        self.cubo = cubo
        self.atual = cubo.get_start()
        self.fechados = []
        self.abertos = []
        self.caminho = []

        self.abertos.append(self.atual)
        self.atual.gScore = 0 # gScore do Start
        self.atual.fScore = self.cubo.get_distance(self.atual, cubo.objetivo)# gScore do Start

        print("  INICIO   {}".format(self.atual.id))
        print("  OBJETIVO {}".format(self.cubo.objetivo.id))

        while( len(self.abertos)!= 0): # Enquanto existir nós abertos
            fScore_vizinho = np.inf
            for i in self.abertos: # Aberto com o menor valor de fScore
                if i.fScore < fScore_vizinho:
                    fScore_vizinho = i.fScore
                    self.atual = i
                    print(" VIZINHO: {0},  CUSTO {1}:".format(self.atual.id, self.atual.fScore))

            print(" ATUAL: {0}:".format(self.atual.id))
            #self.caminho.append(self.atual) # Valor com menor fScore Adicionado ao caminho
            #print(" ATUAL: {0},  CUSTO {1}:".format(self.atual.id, self.atual.fScore))
            if self.atual == cubo.objetivo:
                #self.print_caminho(self.caminho)
                print(" Custo: {}".format(len(self.caminho) -1))
                return self.caminho

            self.abertos.remove(self.atual) # Remove o atual dos abertos
            self.fechados.append(self.atual) # Coloca o atual nos fechados


            for vizinho in self.atual.get_vizinhos():
                if vizinho in self.fechados: continue # Vizinho já foi visitado
                if vizinho == None: continue # Vizinho não é caminho
                if vizinho.blocked == True: continue #Vizinho fechado

                # Distancia do início até um vizinho
                gScore_tentativa = self.atual.gScore + self.cubo.get_distance(self.atual, vizinho)

                if vizinho not in self.abertos: # Adiciona nos abertos
                    self.abertos.append(vizinho)
                elif gScore_tentativa >= vizinho.gScore:
                    continue
                vizinho.gScore = gScore_tentativa
                vizinho.fScore = vizinho.gScore + self.cubo.get_distance(vizinho, cubo.objetivo)

        print("  Não foi encontrado caminho")

    def print_caminho(self, caminho):
        for i in caminho:
            print (" {} ".format(i.id))




def main():
    print(" Função principal")
    cubo_main = Cubo()
    #start = time.perf_counter()
    cubo_main.generate_cubo(3)

    #end = time.perf_counter()
    #print(" {}".format(end-start))
    cubo_main.generate_blocked(0)
    cubo_main.set_start((1, 0, 0))
    #print(" Numero de bloqueados {}".format(cubo_main.numero_bloqueados))
    #cubo_main.set_start()
    cubo_main.set_objetivo((2, 1, 2))
    cubo_main.print_cubo()

    a = A_STAR()
    #start = time.perf_counter()
    #cubo_main.cubo[(2, 2, 4)].print_vizinhos()

    a.find_a_star(cubo_main)

if __name__ == "__main__":
    main()
