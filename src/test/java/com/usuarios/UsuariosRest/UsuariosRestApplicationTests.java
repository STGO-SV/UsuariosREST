package com.usuarios.UsuariosRest;

import com.usuarios.UsuariosRest.models.UsuarioModel;
import com.usuarios.UsuariosRest.repositories.IUsuarioRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class UsuariosRestApplicationTests {
	@Autowired
	private IUsuarioRepository usuarioRepository;

	@Test
	void contextLoads() {
	}

	@Test
	void repositorySavesAndFindsUser() {
		UsuarioModel usuario = new UsuarioModel();
		usuario.setFirstName("Usuario");
		usuario.setLastName("Prueba");
		usuario.setEmail("usuario.prueba@example.test");

		UsuarioModel saved = usuarioRepository.saveAndFlush(usuario);
		Optional<UsuarioModel> found = usuarioRepository.findById(saved.getId());

		assertThat(saved.getId()).isPositive();
		assertThat(found).isPresent();
		assertThat(found.orElseThrow().getEmail()).isEqualTo("usuario.prueba@example.test");
	}

}
